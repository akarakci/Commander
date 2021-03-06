module comm_conviqt_mod
  use sharp
  use healpix_types
  use pix_tools
  use iso_c_binding, only : c_ptr, c_double, c_int
  use comm_map_mod
  implicit none
  include 'fftw3.f'

  private
  public comm_conviqt

  type :: comm_conviqt

    integer(i4b) :: lmax, mmax, bmax, nside, comm, optim, psisteps
    real(dp), allocatable, dimension(:,:)      :: c
    real(dp) :: psires


  contains
    procedure     :: interp
    procedure     :: precompute_sky
    procedure     :: dealloc

  end type comm_conviqt

  interface comm_conviqt
    procedure constructor
  end interface comm_conviqt

contains

  !Constructor

  function constructor(beam, map, optim)
    implicit none
    class(comm_map),           intent(inout) :: beam, map
    class(comm_conviqt), pointer          :: constructor
    integer(i4b),              intent(in) :: optim ! desired optimization flags

    allocate(constructor)

    constructor%lmax = min(beam%info%lmax, map%info%lmax)
    constructor%mmax = constructor%lmax
    constructor%bmax = constructor%lmax

    constructor%nside = beam%info%nside
    constructor%comm = beam%info%comm

    constructor%optim = optim

    !current optimization levels:
    !0 - no optimization
    !1 - use lower resolution psi grid
    !2 - don't interpolate between samples, just use closest


    !make this 2^n
    if (optim > 1) then
      constructor%psires = 2.d0*pi/128
    else 
      constructor%psires = 2.d0*pi/4096
    end if 
    
    constructor%psisteps = int(2*pi/constructor%psires)

    call constructor%precompute_sky(constructor%c, beam, map)

  end function constructor


  !interpolates the precomputed map to the psi angle
  function interp(self, theta, phi, psi)
    implicit none
    class(comm_conviqt),       intent(in) :: self
    real(dp),                  intent(in) :: theta, phi, psi
    real(sp)                              :: interp, x0, x1, unwrap
    integer(i4b)                          :: pixnum, psii, psiu
    
    call ang2pix_ring(self%nside, -theta, phi, pixnum)

    !unwrap psi
    if (psi < 0) then
      unwrap = psi + 2*pi
    else
      unwrap = psi
    end if

    if (self%optim > 2) then
      interp = self%c(pixnum, nint(unwrap / self%psires))
      return
    end if

    !index of the lower bound of psi in the array
    psii = int(unwrap / self%psires)
    !index of the upper bound of psi
    psiu = psii + 1
    if (psiu >= self%psisteps) then !catch rollover
      psiu = 0
    end if
    
    !linear interpolation between evaluated samples in psi
    ! y = (y_0 (x_1 - x) + y_1 (x - x_0))/(x_1 - x_0)
    x0 = psii * self%psires
    x1 = psiu * self%psires
    interp = ((self%c(pixnum, psii)) * (x1 - unwrap) + self%c(pixnum, psiu) * (unwrap - x0))/(x1 - x0)

  end function interp

  !precomputes the maps and stores to the allocated array
  !TODO: handle polarized sidelobes?
  subroutine precompute_sky(self, c, beam, map)
    implicit none
    class(comm_conviqt),                          intent(in) :: self
    real(dp), allocatable, dimension(:,:),        intent(out):: c  
    class(comm_map),                              intent(inout):: beam, map
    integer(i4b) :: i,j,k,np,l,m_s, m_b, pixNum
    real(dp) :: theta, phi, psi
    complex(dpc) :: alm_b, alm_s
    real(dp), allocatable, dimension(:,:) :: marray
    real(c_double), allocatable, dimension(:,:,:) :: alm    
    real(c_double), allocatable, dimension(:,:) :: mout
    integer*8 :: fft_plan
    real(sp), allocatable, dimension(:) :: dt
    complex(spc), allocatable, dimension(:) :: dv

    np = map%info%np

    allocate(c(1:np, 0:self%psisteps -1))
    c = 0

    allocate(marray(1:np, -self%bmax:self%bmax))
    marray = 0

    !transform to spherical harmonics
    call map%YtW()
    call beam%YtW()

    allocate(alm(0:map%info%nalm-1, 0:beam%info%nalm, 2))
    allocate(mout(0:beam%info%np-1, 2))

    !check lmaxes
    if (beam%info%lmax > map%info%lmax) then
      write(*,*) "possible problem with not enought ms in precompute_sky"
      stop
    endif

    !copy to alm array 
    do i=0, map%info%nalm-1
      l = map%info%lm(i,1)      
      m_s = map%info%lm(i,2)
      do j=0, beam%info%nalm-1
        m_b = beam%info%lm(j,2)
        !TODO: math to figure out what these terms actually are
        call beam%get_alm(l, m_b, 0, .true., alm_b)
        call beam%get_alm(l, m_s, 0, .true., alm_s)   

        alm(i, j, 1) = -1 ** m_s * sqrt(4*pi/(2*l + 1)) * real(conjg(alm_b) * alm_s) !real part
        alm(i, j, 2) = -1 ** m_s * sqrt(4*pi/(2*l + 1)) * aimag(conjg(alm_b) * alm_s) !imag part
      end do
    end do

    call sharp_execute(SHARP_Y, 0, 1, alm(:, 0, 1:1), beam%info%alm_info, mout(:,1:1), beam%info%geom_info_T, comm=self%comm)

    !copy to m array
    do j=0, np
      marray(j, 0) = mout(j, 1)
    end do


    do i=1, self%bmax
      alm = 0
      call sharp_execute(SHARP_Y, i, 2, alm(:,i,1:2), beam%info%alm_info, mout(:,1:2), beam%info%geom_info_P, comm=self%comm)
      !copy to m array
      do j=0, np
        marray(j, -i) = mout(j, 2)
        marray(j, i) = mout(j, 1)
      end do
    end do

    allocate(dt(self%psisteps), dv(self%psisteps/2))

    call dfftw_plan_dft_c2r_1d(fft_plan, self%psisteps, dt, dp, fftw_estimate + fftw_unaligned)

    do i=1, np
      call pix2ang_ring(self%nside, i-1, theta, phi) 
      pixNum = beam%info%pix(i)

      dt = 0
      dv = 0
      !do fft of data, store to dt

      dv(1) = marray(pixNum, 0)
      do j=2, self%bmax
        dv(j) = cmplx(marray(pixNum, j-1), marray(pixNum, -j+1))
      end do

      call dfftw_execute_dft_c2r(fft_plan, dv, dt)

      !copy to c
      do j = 0, self%psisteps
        c(beam%info%pix(i), j) = dt(j)
      end do

    end do
 
  deallocate(dt, dv)
  
  call dfftw_destroy_plan(fft_plan)

  !bcast to all cores

  end subroutine precompute_sky

  !dealocate memory used by the class
  subroutine dealloc(self)
    implicit none
    class(comm_conviqt),                          intent(inout) :: self

    deallocate(self%c)
  end subroutine dealloc
end module comm_conviqt_mod
