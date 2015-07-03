module comm_cr_mod
  use comm_comp_mod
  use comm_data_mod
  use comm_param_mod
  use comm_diffuse_comp_mod
  use comm_template_comp_mod
  use rngmod
  implicit none

  private
  public solve_cr_eqn_by_CG, cr_amp2x, cr_x2amp, cr_computeRHS, cr_matmulA

  interface cr_amp2x
     module procedure cr_amp2x_full
  end interface cr_amp2x

  interface cr_x2amp
     module procedure cr_x2amp_full
  end interface cr_x2amp

  interface cr_insert_comp
     module procedure cr_insert_comp_1d, cr_insert_comp_2d
  end interface cr_insert_comp

  interface cr_extract_comp
     module procedure cr_extract_comp_1d, cr_extract_comp_2d
  end interface cr_extract_comp

contains

  recursive subroutine solve_cr_eqn_by_CG(cpar, A, invM, x, b, stat, Nscale)
    implicit none

    type(comm_params),                intent(in)             :: cpar
    real(dp),          dimension(1:), intent(out)            :: x
    real(dp),          dimension(1:), intent(in)             :: b
    integer(i4b),                     intent(out)            :: stat
    real(dp),                         intent(in),   optional :: Nscale

    interface
       recursive function A(x, Nscale)
         use healpix_types
         implicit none
         real(dp), dimension(:),       intent(in)           :: x
         real(dp), dimension(size(x))                       :: A
         real(dp),                     intent(in), optional :: Nscale
       end function A

       recursive function invM(x, Nscale)
         use healpix_types
         implicit none
         real(dp), dimension(:),      intent(in)           :: x
         real(dp), dimension(size(x))                      :: invM
         real(dp),                    intent(in), optional :: Nscale
       end function invM
    end interface

    integer(i4b) :: i, j, k, l, m, n, maxiter, root
    real(dp)     :: eps, tol, delta0, delta_new, delta_old, alpha, beta, t1, t2
    real(dp), allocatable, dimension(:) :: Ax, r, d, q, invM_r, temp_vec, s

    root    = 0
    maxiter = cpar%cg_maxiter
    eps     = cpar%cg_tol
    n       = size(x)

    ! Allocate temporary data vectors
    allocate(Ax(n), r(n), d(n), q(n), invM_r(n), s(n))

    ! Initialize the CG search
    x  = 0.d0
    r  = b-A(x)
    d  = invM(r)

    delta_new = dot_product(r,d)
    delta0    = delta_new
    do i = 1, maxiter
       call wall_time(t1)
       
       if (delta_new < eps**2 * delta0) exit

       q     = A(d)
       alpha = delta_new / dot_product(d, q)
       x     = x + alpha * d

       ! Restart every 50th iteration to suppress numerical errors
       if (mod(i,50) == 0) then
          r = b - A(x)
       else
          r = r - alpha*q
       end if

       s         = invM(r)
       delta_old = delta_new 
       delta_new = dot_product(r, s)
       beta      = delta_new / delta_old
       d         = s + beta * d

       call wall_time(t2)
       if (cpar%myid == root .and. cpar%verbosity > 2) then
          write(*,fmt='(a,i5,a,e8.3,a,e8.3,a,f8.3)') 'CG iter. ', i, ' -- res = ', &
               & real(delta_new,sp), ', tol = ', real(eps**2 * delta0,sp), &
               & ', wall time = ', real(t2-t1,sp)
       end if

    end do

    if (i >= maxiter) then
       write(*,*) 'ERROR: Convergence in CG search not reached within maximum'
       write(*,*) '       number of iterations = ', maxiter
       stat = stat + 1
    else
       if (cpar%myid == root .and. cpar%verbosity > 1) then
          write(*,fmt='(a,i5,a,e8.3,a,e8.3,a,f8.3)') 'Final CG iter ', i-1, ' -- res = ', &
               & real(delta_new,sp), ', tol = ', real(eps**2 * delta0,sp)
       end if
    end if

    deallocate(Ax, r, d, q, invM_r, s)
    
  end subroutine solve_cr_eqn_by_CG

  function cr_amp2x_full()
    implicit none

    real(dp), allocatable, dimension(:) :: cr_amp2x_full

    integer(i4b) :: i, ind
    class(comm_comp), pointer :: c

    ! Stack parameters linearly
    allocate(cr_amp2x_full(ncr))
    ind = 1
    c   => compList
    do while (associated(c))
       select type (c)
       class is (comm_diffuse_comp)
          do i = 1, c%x%info%nmaps
             cr_amp2x_full(ind:ind+c%x%info%nalm-1) = c%x%alm(:,i)
             ind = ind + c%x%info%nalm
          end do
       end select
       c => c%next()
    end do

  end function cr_amp2x_full

  subroutine cr_x2amp_full(x)
    implicit none

    real(dp), dimension(:), intent(in) :: x

    integer(i4b) :: i, ind
    class(comm_comp), pointer :: c

    ind = 1
    c   => compList
    do while (associated(c))
       select type (c)
       class is (comm_diffuse_comp)
          do i = 1, c%x%info%nmaps
             c%x%alm(:,i) = x(ind:ind+c%x%info%nalm-1)
             ind = ind + c%x%info%nalm
          end do
       end select
       c => c%next()
    end do
    
  end subroutine cr_x2amp_full

  subroutine cr_insert_comp_1d(id, add, x_in, x_out)
    implicit none

    integer(i4b),                 intent(in)    :: id
    logical(lgt),                 intent(in)    :: add
    real(dp),     dimension(:),   intent(in)    :: x_in
    real(dp),     dimension(:),   intent(inout) :: x_out

    integer(i4b) :: i, n, pos

    n   = size(x_in,1)
    if (add) then
       x_out(pos:pos+n-1) = x_out(pos:pos+n-1) + x_in
    else
       x_out(pos:pos+n-1) = x_in
    end if
    
  end subroutine cr_insert_comp_1d

  subroutine cr_insert_comp_2d(id, add, x_in, x_out)
    implicit none

    integer(i4b),                 intent(in)    :: id
    logical(lgt),                 intent(in)    :: add
    real(dp),     dimension(:,:), intent(in)    :: x_in
    real(dp),     dimension(:),   intent(inout) :: x_out

    integer(i4b) :: i, n, pos

    n   = size(x_in,1)
    pos = ind_comp(id,1)
    do i = 1, size(x_in,2)
       if (add) then
          x_out(pos:pos+n-1) = x_out(pos:pos+n-1) + x_in(:,i)
       else
          x_out(pos:pos+n-1) = x_in(:,i)
       end if
       pos                = pos+n
    end do
    
  end subroutine cr_insert_comp_2d


  subroutine cr_extract_comp_1d(id, x_in, x_out)
    implicit none

    integer(i4b),                            intent(in)  :: id
    real(dp),     dimension(:),              intent(in)  :: x_in
    real(dp),     dimension(:), allocatable, intent(out) :: x_out

    integer(i4b) :: i, n, pos, nmaps

    pos   = ind_comp(id,1)
    n     = ind_comp(id,2)
    allocate(x_out(n))
    x_out = x_in(pos:pos+n-1)
    
  end subroutine cr_extract_comp_1d

  subroutine cr_extract_comp_2d(id, x_in, x_out)
    implicit none

    integer(i4b),                              intent(in)  :: id
    real(dp),     dimension(:),                intent(in)  :: x_in
    real(dp),     dimension(:,:), allocatable, intent(out) :: x_out

    integer(i4b) :: i, n, pos, nmaps

    pos   = ind_comp(id,1)
    nmaps = ind_comp(id,3)
    n     = ind_comp(id,2)/nmaps
    allocate(x_out(n,nmaps))
    do i = 1, nmaps
       x_out(:,i) = x_in(pos:pos+n-1)
       pos        = pos + n
    end do
    
  end subroutine cr_extract_comp_2d

  ! ---------------------------
  ! Definition of linear system
  ! ---------------------------

  subroutine cr_computeRHS(handle, rhs)
    implicit none

    type(planck_rng),                intent(inout) :: handle
    real(dp),         dimension(1:), intent(out)   :: rhs

    integer(i4b) :: i, j, k, l, m, n, ierr
    real(dp)     :: omega
    class(comm_map),  pointer                  :: map, alms, Tm
    class(comm_comp), pointer                  :: c     
    real(dp),        allocatable, dimension(:) :: eta

    n = size(rhs)

    ! Add channel dependent terms
    rhs = 0.d0
    do i = 1, numband

       ! Set up Wiener filter term
       map => comm_map(data(i)%map)
       call data(i)%N%sqrtInvN(map)
       
       ! Add channel-dependent white noise fluctuation
       do k = 1, map%info%nmaps
          do j = 0, map%info%np-1
             map%map(j,k) = map%map(j,k) + rand_gauss(handle)
          end do
       end do

       ! Multiply with sqrt(invN)
       call data(i)%N%sqrtInvN(map)

       ! Convolve with transpose beam
       call data(i)%B%conv(alm_in=.false., alm_out=.false., trans=.true., map=map)

       ! Multiply with (transpose and component specific) mixing matrix, and
       ! insert into correct segment
       c => compList
       do while (associated(c))
          select type (c)
          class is (comm_diffuse_comp)
             Tm     => comm_map(map)
             Tm%map = c%F(i)%p%map * Tm%map
             call Tm%Yt
             if (trim(c%cltype) /= 'none') then
                ! Multiply with inv(sqrt(C_l))
             end if
             call cr_insert_comp(c%id, .false., Tm%alm, rhs)
             nullify(Tm)
          end select
          c => c%next()
       end do

       nullify(map)
    end do

    ! Add prior dependent terms
    c => compList
    do while (associated(c))
       select type (c)
       class is (comm_diffuse_comp)
          if (trim(c%cltype) == 'none') cycle
          n = ind_comp(c%id,2)
          allocate(eta(n))
          do i = 1, n
             eta(i) = rand_gauss(handle)
          end do
          call cr_insert_comp(c%id, .true., Tm%alm, rhs)
          deallocate(eta)
       end select
       c => c%next()
    end do
    
  end subroutine cr_computeRHS

  subroutine cr_matmulA(x)
    implicit none

    real(dp), dimension(1:), intent(inout) :: x

    real(dp)                  :: t1, t2
    integer(i4b)              :: i
    class(comm_map),  pointer :: map
    class(comm_comp), pointer :: c
    real(dp),        allocatable, dimension(:)   :: y
    real(dp),        allocatable, dimension(:,:) :: alm, m

    ! Initialize output array
    allocate(y(ncr))
    y = 0.d0

    ! Add frequency dependent terms
    do i = 1, numband

       ! Compute component-summed map, ie., column-wise matrix elements
       map => comm_map(data(i)%info)
       c   => compList
       do while (associated(c))
          select type (c)
          class is (comm_diffuse_comp)
             call cr_extract_comp(c%id, y, alm)
             m = c%getBand(i, amp_in=alm)
             map%map = map%map + m
             deallocate(alm, m)
          end select
          c => c%next()
       end do

       ! Multiply with invN
       call data(i)%N%InvN(map)

       ! Project summed map into components, ie., row-wise matrix elements
       c   => compList
       do while (associated(c))
          select type (c)
          class is (comm_diffuse_comp)
             alm = c%projectBand(i, map)
             call cr_insert_comp(c%id, .true., alm, y)
             deallocate(alm)
          end select
          c => c%next()
       end do
       
    end do

    ! Add prior terms
    c   => compList
    do while (associated(c))
       select type (c)
       class is (comm_diffuse_comp)
          if (trim(c%cltype) == 'none') cycle
          allocate(alm(c%x%info%nalm,c%x%info%nmaps))
          call cr_extract_comp(c%id, x, alm)
          call cr_insert_comp(c%id, .true., alm, y)
          deallocate(alm)
       end select
       c => c%next()
    end do

    ! Return result and clean up
    x = y

    deallocate(y)

  end subroutine cr_matmulA
  
end module comm_cr_mod
