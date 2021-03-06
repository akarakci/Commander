program commander
  use comm_param_mod
  use comm_data_mod
  use comm_signal_mod
  use comm_cr_mod
  use comm_chisq_mod
  use comm_output_mod
  use comm_comp_mod
  use comm_nonlin_mod
  implicit none

  ! *********************************************************************
  ! *      Commander -- An MCMC code for global, exact CMB analysis     *
  ! *                                                                   *
  ! *                 Written by Hans Kristian Eriksen                  *
  ! *                                                                   *
  ! *                Copyright 2015, all rights reserved                *
  ! *                                                                   *
  ! *                                                                   *
  ! *   NB! The code is provided as is, and *no* guarantees are given   *
  ! *       as far as either accuracy or correctness goes. Even though  *
  ! *       it is fairly well tested, there may be (and likely are)     *
  ! *       bugs in this code.                                          *
  ! *                                                                   *
  ! *  If used for published results, please cite these papers:         *
  ! *                                                                   *
  ! *      - Jewell et al. 2004, ApJ, 609, 1                            *
  ! *      - Wandelt et al. 2004, Phys. Rev. D, 70, 083511              *
  ! *      - Eriksen et al. 2004, ApJS, 155, 227 (Commander)            *
  ! *      - Eriksen et al. 2008, ApJ, 676, 10  (Joint FG + CMB)        *
  ! *                                                                   *
  ! *********************************************************************

  integer(i4b)        :: i, iargc, ierr, iter, stat, first_sample, samp_group
  real(dp)            :: t0, t1, t2, t3
  type(comm_params)   :: cpar
  type(planck_rng)    :: handle, handle_noise

  type(comm_mapinfo), pointer :: info
  type(comm_map), pointer :: m
  class(comm_comp), pointer :: c1

  ! **************************************************************
  ! *          Get parameters and set up working groups          *
  ! **************************************************************
  call wall_time(t0)
  call mpi_init(ierr)
  call mpi_comm_rank(MPI_COMM_WORLD, cpar%myid, ierr)
  call mpi_comm_size(MPI_COMM_WORLD, cpar%numprocs, ierr)
  cpar%root = 0
    
  
  if (cpar%myid == cpar%root) call wall_time(t1)
  call read_comm_params(cpar)
  if (cpar%myid == cpar%root) call wall_time(t3)
  
  call initialize_mpi_struct(cpar, handle, handle_noise)
  call validate_params(cpar)  
  call init_status(status, trim(cpar%outdir)//'/comm_status.txt')
  status%active = cpar%myid == 0 !.false.
  
  if (iargc() == 0) then
     if (cpar%myid == cpar%root) write(*,*) 'Usage: commander [parfile] {sample restart}'
     call mpi_finalize(ierr)
     stop
  end if
  if (cpar%myid == cpar%root) call wall_time(t2)

  ! Output a little information to notify the user that something is happening
  if (cpar%myid == cpar%root .and. cpar%verbosity > 0) then
     write(*,*) ''
     write(*,*) '       **********   Commander   *************'
     write(*,*) ''
     write(*,*) '   Number of chains                       = ', cpar%numchain
     write(*,*) '   Number of processors in first chain    = ', cpar%numprocs_chain
     write(*,*) ''
     write(*,fmt='(a,f12.3,a)') '   Time to initialize run = ', t2-t0, ' sec'
     write(*,fmt='(a,f12.3,a)') '   Time to read in parameters = ', t3-t1, ' sec'
     write(*,*) ''

  end if

  ! ************************************************
  ! *               Initialize modules             *
  ! ************************************************

  if (cpar%myid == cpar%root) call wall_time(t1)

  call update_status(status, "init")
  if (cpar%enable_tod_analysis) call initialize_tod_mod(cpar)
  call initialize_bp_mod(cpar);            call update_status(status, "init_bp")
  call initialize_data_mod(cpar, handle);  call update_status(status, "init_data")
  call initialize_signal_mod(cpar);        call update_status(status, "init_signal")
  call initialize_from_chain(cpar);        call update_status(status, "init_from_chain")

  if (cpar%output_input_model) then
     if (cpar%myid == 0) write(*,*) 'Outputting input model to sample number 999999'
     call output_FITS_sample(cpar, 999999, .false.)
     call mpi_finalize(ierr)
     stop
  end if

  ! Output SEDs for each component
  if (cpar%output_debug_seds) then
     if (cpar%myid == cpar%root) call dump_components('sed.dat')
     call mpi_finalize(ierr)
     stop
  end if
  
  if (cpar%myid == cpar%root) call wall_time(t2)
  
  ! **************************************************************
  ! *                   Carry out computations                   *
  ! **************************************************************

  if (cpar%myid == cpar%root .and. cpar%verbosity > 0) then 
     write(*,*) ''
     write(*,fmt='(a,f12.3,a)') '   Time to read data = ', t2-t1, ' sec'
     write(*,*) '   Starting Gibbs sampling'
  end if
  ! Initialize output structures

  ! Run Gibbs loop
  first_sample = 1
  do iter = first_sample, cpar%num_gibbs_iter

     if (cpar%myid == 0) then
        call wall_time(t1)
        write(*,fmt='(a)') '---------------------------------------------------------------------'
        write(*,fmt='(a,i4,a,i8)') 'Chain = ', cpar%mychain, ' -- Iteration = ', iter
     end if

     ! Process TOD structures
     if (cpar%enable_TOD_analysis) call process_TOD(cpar)


     ! Sample linear parameters with CG search; loop over CG sample groups
     if (cpar%sample_signal_amplitudes) then
        do samp_group = 1, cpar%cg_num_samp_groups
           if (cpar%myid == 0) then
              write(*,fmt='(a,i4,a,i4,a,i4)') '  Chain = ', cpar%mychain, ' -- CG sample group = ', &
                   & samp_group, ' of ', cpar%cg_num_samp_groups
           end if
           call sample_amps_by_CG(cpar, samp_group, handle, handle_noise)
        end do
     end if

     ! Output sample to disk
     call output_FITS_sample(cpar, iter, .true.)

     ! Sample partial-sky templates
     !call sample_partialsky_tempamps(cpar, handle)

     !call output_FITS_sample(cpar, 1000, .true.)

     ! Sample non-linear parameters
     do i = 1, cpar%num_ind_cycle
        call sample_nonlin_params(cpar, iter, handle)
     end do

     ! Sample instrumental parameters

     ! Sample power spectra
     

     ! Compute goodness-of-fit statistics
     
     if (cpar%myid == 0) then
        call wall_time(t2)
        write(*,fmt='(a,i4,a,f12.3,a)') 'Chain = ', cpar%mychain, ' -- wall time = ', t2-t1, ' sec'
     end if
     
  end do

  
  ! **************************************************************
  ! *                   Exit cleanly                             *
  ! **************************************************************

  ! Wait for everybody to exit
  call mpi_barrier(MPI_COMM_WORLD, ierr)

  ! Clean up
  if (cpar%myid == cpar%root .and. cpar%verbosity > 1) write(*,*) '     Cleaning up and finalizing'

  ! And exit
  call free_status(status)
  call mpi_finalize(ierr)


contains

  subroutine process_TOD(cpar)
    implicit none
    type(comm_params), intent(in) :: cpar

    integer(i4b) :: i, j, ndet
    type(map_ptr), allocatable, dimension(:) :: s_sky

    do i = 1, numband
       if (trim(cpar%ds_tod_type(i)) == 'none') cycle

       ! Compute current sky signal
       allocate(s_sky(data(i)%tod%ndet))
       do j = 1, data(i)%tod%ndet
          s_sky(j)%p => comm_map(data(i)%info)
          call get_sky_signal(i, j, s_sky(j)%p)  ! Currently returns the same signal for each detector
       end do

       ! Process TOD, get new map and rms map
       call data(i)%tod%process_tod(s_sky, data(i)%map, data(i)%N%siN)

    end do

  end subroutine process_TOD

end program commander
