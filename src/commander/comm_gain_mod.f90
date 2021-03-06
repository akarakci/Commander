module comm_gain_mod
  use comm_param_mod
  use comm_data_mod
  use comm_comp_mod
  implicit none

contains
  
  subroutine sample_gain(band, outdir, chain, iter, handle)
    implicit none
    integer(i4b),     intent(in)    :: band
    character(len=*), intent(in)    :: outdir
    integer(i4b),     intent(in)    :: chain, iter
    type(planck_rng), intent(inout) :: handle

    integer(i4b)  :: i, l, lmin, lmax, ierr, root, ncomp, dl_low, dl_high
    real(dp)      :: my_sigma, my_mu, mu, sigma, gain_new, chisq, mychisq
    real(dp)      :: MAX_DELTA_G = 0.01d0
    character(len=4) :: chain_text
    character(len=6) :: iter_text
    real(dp), allocatable, dimension(:,:) :: m, cls1, cls2
    class(comm_comp),   pointer           :: c
    class(comm_map), pointer              :: invN_sig, map, sig, res

    ierr    = 0
    root    = 0
    dl_low  = 10
    dl_high = 25

    ! Build reference signal
    sig => comm_map(data(band)%info)
    res => comm_map(data(band)%info)
    c => compList
    do while (associated(c))
       if (trim(c%label) /= trim(data(band)%gain_comp) .and. trim(data(band)%gain_comp) /= 'all') then
          c => c%next()
          cycle
       end if
       
       ! Add current component to calibration signal
       allocate(m(0:data(band)%info%np-1,data(band)%info%nmaps))
       m       = c%getBand(band)
       sig%map = sig%map + m
       deallocate(m)
       c => c%next()
    end do

    ! Add reference signal to residual
    res%map = data(band)%res%map + sig%map

    ! Divide by old gain
    sig%map = sig%map / data(band)%gain

    lmin = data(band)%gain_lmin
    lmax = data(band)%gain_lmax
    if (lmin > 0 .and. lmax > 0) then

       ! Apply mask
       if (associated(data(band)%gainmask)) then
          sig%map = sig%map * data(band)%gainmask%map
          res%map = res%map * data(band)%gainmask%map
       end if

       ! Compute cross-spectrum
       allocate(cls1(0:sig%info%lmax,sig%info%nspec))
       allocate(cls2(0:res%info%lmax,res%info%nspec))
       call sig%YtW
       call res%YtW

       call sig%getSigmaL(cls1)
       call sig%getCrossSigmaL(res, cls2)

       data(band)%gain = mean(cls2(lmin:lmax,1)/cls1(lmin:lmax,1))

       if (data(band)%info%myid == root) then
          call int2string(chain, chain_text)
          call int2string(iter,  iter_text)
          open(58,file=trim(outdir)//'/gain_cl_'//trim(data(band)%label)//'_c'//chain_text//'_k'//iter_text//'.dat', recl=1024)
          write(58,*) '#  ell     Ratio    C_l_cross     C_l_sig'
          do l = lmin, lmax
             write(58,*) l, cls2(l,1)/cls1(l,1), cls2(l,1), cls1(l,1)
          end do
          close(58)
       end if

       deallocate(cls1, cls2)

    else
       ! Correlate in pixel space with standard likelihood fit
       invN_sig     => comm_map(sig)
       call data(band)%N%invN(invN_sig)! Multiply with (invN)
       if (associated(data(band)%gainmask)) invN_sig%map = invN_sig%map * data(band)%gainmask%map

       !call invN_sig%writeFITS('invN_sig_'//trim(data(band)%label)//'.fits')

       my_sigma = sum(sig%map * invN_sig%map)
       my_mu    = sum(res%map * invN_sig%map)
       call mpi_reduce(my_mu,    mu,    1, MPI_DOUBLE_PRECISION, MPI_SUM, root, data(band)%info%comm, ierr)
       call mpi_reduce(my_sigma, sigma, 1, MPI_DOUBLE_PRECISION, MPI_SUM, root, data(band)%info%comm, ierr)
       if (data(band)%info%myid == root) then
          ! Compute mu and sigma from likelihood term
          mu       = mu / sigma
          sigma    = sqrt(1.d0 / sigma)
          if (.true.) then ! Optimize
             gain_new = mu
          else
             gain_new = mu + sigma * rand_gauss(handle)
          end if
          ! Only allow relatively small changes between steps, and not outside the range from 0.01 to 0.01
          data(band)%gain = min(max(gain_new, data(band)%gain-MAX_DELTA_G), data(band)%gain+MAX_DELTA_G)
       end if

       ! Distribute new gaxins
       call mpi_bcast(data(band)%gain, 1, MPI_DOUBLE_PRECISION, 0, data(band)%info%comm, ierr)

       call invN_sig%dealloc()
    end if

    ! Subtract scaled reference signal to residual
    data(band)%res%map = res%map - data(band)%gain * sig%map

    ! Output residual signal and residual for debugging purposes
    if (.false.) then
       call sig%writeFITS('gain_sig_'//trim(data(band)%label)//'.fits')
       call res%writeFITS('gain_res_'//trim(data(band)%label)//'.fits')
    end if

    call sig%dealloc()
    call res%dealloc()

  end subroutine sample_gain


end module comm_gain_mod
