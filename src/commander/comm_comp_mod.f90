module comm_comp_mod
  use comm_param_mod
  use comm_bp_utils
  use comm_bp_mod
  implicit none

  private
  public  :: comm_comp, ncomp, compList
  
  !**************************************************
  !        Generic component class definition
  !**************************************************
  type, abstract :: comm_comp
     ! Linked list variables
     class(comm_comp), pointer :: nextLink => null()
     class(comm_comp), pointer :: prevLink => null()

     ! Data variables
     character(len=512) :: label, class, type, unit
     integer(i4b)       :: nside, npar, nx, x0
     logical(lgt)       :: active, pol
     real(dp)           :: nu_ref, RJ2unit_
     real(dp), allocatable, dimension(:)     :: theta_def
     real(dp), allocatable, dimension(:,:)   :: p_gauss
     real(dp), allocatable, dimension(:,:)   :: p_uni

   contains
     ! Linked list procedures
     procedure :: next    ! get the link after this link
     procedure :: prev    ! get the link before this link
     procedure :: setNext ! set the link after this link
     procedure :: add     ! add new link at the end

     ! Data procedures
     procedure                       :: initComp
     procedure(evalSED),    deferred :: S
!     procedure(evalMixmat), deferred :: F
!     procedure(evalAmp),    deferred :: a
!     procedure(simComp),    deferred :: sim
     procedure                       :: dumpSED
!     procedure(dumpHDF),    deferred :: dumpHDF
!     procedure(dumpFITS),   deferred :: dumpFITS
     procedure                       :: RJ2unit
  end type comm_comp

  abstract interface
     ! Evaluate SED in brightness temperature normalized to reference frequency
     function evalSED(self, nu, band, theta)
       import comm_comp, dp, i4b
       class(comm_comp),        intent(in)           :: self
       real(dp),                intent(in), optional :: nu
       integer(i4b),            intent(in), optional :: band
       real(dp), dimension(1:), intent(in), optional :: theta
       real(dp)                                      :: evalSED
     end function evalSED

!!$     ! Evaluate amplitude map in brightness temperature at reference frequency
!!$     function evalAmp(self, nside, nmaps, pix, x_1D, x_2D)
!!$       import comm_comp, dp, i4b
!!$       class(comm_comp),                          intent(in)           :: self
!!$       integer(i4b),                              intent(in)           :: nside, nmaps
!!$       integer(i4b),              dimension(:),   intent(in), optional :: pix
!!$       real(dp),                  dimension(:),   intent(in), optional :: x_1D
!!$       real(dp),                  dimension(:,:), intent(in), optional :: x_2D
!!$       real(dp),     allocatable, dimension(:,:)                       :: evalAmp
!!$     end function evalAmp
!!$
!!$     ! Evaluate mixing matrix in brightness temperature at reference frequency
!!$     function evalMixmat(self, nside, nmaps, pix)
!!$       import comm_comp, dp, i4b
!!$       class(comm_comp),                        intent(in)           :: self
!!$       integer(i4b),                            intent(in)           :: nside, nmaps
!!$       integer(i4b),              dimension(:), intent(in), optional :: pix
!!$       real(dp),     allocatable, dimension(:,:)                     :: evalMixmat
!!$     end function evalMixmat
!!$
!!$     ! Generate simulated component
!!$     function simComp(self, handle, nside, nmaps, pix)
!!$       import planck_rng, comm_comp, dp, i4b
!!$       class(comm_comp),                        intent(in)           :: self
!!$       type(planck_rng),                        intent(inout)        :: handle
!!$       integer(i4b),                            intent(in)           :: nside, nmaps
!!$       integer(i4b),              dimension(:), intent(in), optional :: pix
!!$       real(dp),     allocatable, dimension(:,:)                     :: simComp
!!$     end function simComp
!!$
!!$     ! Dump current sample to HDF chain files
!!$     subroutine dumpHDF(self, filename)
!!$       import comm_comp
!!$       class(comm_comp),                        intent(in)           :: self
!!$       character(len=*),                        intent(in)           :: filename
!!$     end subroutine dumpHDF
!!$
!!$     ! Dump current sample to HEALPix FITS file
!!$     subroutine dumpFITS(self, dir)
!!$       import comm_comp
!!$       class(comm_comp),                        intent(in)           :: self
!!$       character(len=*),                        intent(in)           :: dir
!!$     end subroutine dumpFITS
  end interface

  !**************************************************
  !             Auxiliary variables
  !**************************************************

  integer(i4b)              :: n_dump = 1000
  real(dp),    dimension(2) :: nu_dump = [0.1d9, 3000.d9] 

  !**************************************************
  !             Internal module variables
  !**************************************************
  integer(i4b)              :: ncomp
  class(comm_comp), pointer :: compList, currComp => null()
  
contains

  subroutine initComp(self, cpar, id)
    implicit none
    class(comm_comp)               :: self
    type(comm_params),  intent(in) :: cpar
    integer(i4b),       intent(in) :: id

    self%active = cpar%cs_include(id)
    self%label  = cpar%cs_label(id)
    self%type   = cpar%cs_type(id)
    self%class  = cpar%cs_class(id)
    self%pol    = cpar%cs_polarization(id)
    self%nside  = cpar%cs_nside(id)
    self%unit   = cpar%cs_unit(id)
    self%nu_ref = cpar%cs_nu_ref(id)

    ! Set up conversion factor between RJ and native component unit
    select case (trim(self%unit))
    case ('uK_cmb')
       self%RJ2unit_ = comp_a2t(self%nu_ref)
    case ('MJy/sr') 
       self%RJ2unit_ = comp_bnu_prime_RJ(self%nu_ref) * 1e14
    case ('K km/s') 
       self%RJ2unit_ = -1.d30
    case ('y_SZ') 
       self%RJ2unit_ = 2.d0*self%nu_ref**2*k_b/c**2 / &
               & (comp_bnu_prime(self%nu_ref) * comp_sz_thermo(self%nu_ref))
    case ('uK_RJ') 
       self%RJ2unit_ = 1.d0
    case default
       call report_error('Unsupported unit: ' // trim(self%unit))
    end select

  end subroutine initComp

  subroutine dumpSED(self, unit)
    implicit none
    class(comm_comp), intent(in) :: self
    integer(i4b),     intent(in) :: unit

    integer(i4b) :: i
    real(dp)     :: nu, dnu

    nu = nu_dump(1)
    dnu = (nu_dump(2)/nu_dump(1))**(1.d0/(n_dump-1))
    do i = 1, n_dump
       write(unit,*) nu*1d-9, self%S(nu, theta=self%theta_def(1:self%npar))
       nu = nu*dnu
    end do
    
  end subroutine dumpSED

  function RJ2unit(self, bp)
    implicit none

    class(comm_comp), intent(in)           :: self
    class(comm_bp),   intent(in), optional :: bp
    real(dp)                               :: RJ2unit

    if (present(bp)) then
       if (trim(self%unit) == 'K km/s') then
          RJ2unit = 1.d0 / bp%lineAmp_RJ(self%nu_ref)
       else
          RJ2unit = self%RJ2unit_
       end if
    else
       RJ2unit = self%RJ2unit_
    end if
    
  end function RJ2unit
  
  function next(self)
    class(comm_comp) :: self
    class(comm_comp), pointer :: next
    next => self%nextLink
  end function next

  function prev(self)
    class(comm_comp) :: self
    class(comm_comp), pointer :: prev
    prev => self%prevLink
  end function prev
  
  subroutine setNext(self,next)
    class(comm_comp) :: self
    class(comm_comp), pointer :: next
    self%nextLink => next
  end subroutine setNext

  subroutine add(self,link)
    class(comm_comp)         :: self
    class(comm_comp), target :: link

    class(comm_comp), pointer :: c
    
    c => self%nextLink
    do while (associated(c%nextLink))
       c => c%nextLink
    end do
    link%prevLink => c
    c%nextLink    => link
  end subroutine add
  
end module comm_comp_mod
