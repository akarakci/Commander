module comm_diffuse_comp_mod
  use comm_param_mod
  use comm_comp_mod
  implicit none

  private
  public comm_diffuse_comp
  
  !**************************************************
  !            Diffuse component class
  !**************************************************
  type, abstract, extends (comm_comp) :: comm_diffuse_comp
     character(len=512) :: cltype
     integer(i4b)       :: lpiv
     real(dp), allocatable, dimension(:,:) :: cls
     real(dp), allocatable, dimension(:,:) :: mask
   contains
     procedure :: initDiffuse
     procedure :: a        => evalDiffuseAmp
     procedure :: F        => evalDiffuseMixmat
     procedure :: sim      => simDiffuseComp
     procedure :: dumpHDF  => dumpDiffuseToHDF
     procedure :: dumpFITS => dumpDiffuseToFITS
  end type comm_diffuse_comp

contains

  subroutine initDiffuse(self, cpar, id)
    implicit none
    class(comm_diffuse_comp)            :: self
    type(comm_params),       intent(in) :: cpar
    integer(i4b),            intent(in) :: id

    call self%initComp(cpar, id)

    ! Initialize variables specific to diffuse source type

  end subroutine initDiffuse

  ! Evaluate amplitude map in brightness temperature at reference frequency
  function evalDiffuseAmp(self, nside, nmaps, pix, x_1D, x_2D)
    class(comm_diffuse_comp),                  intent(in)           :: self
    integer(i4b),                              intent(in)           :: nside, nmaps
    integer(i4b),              dimension(:),   intent(in), optional :: pix
    real(dp),                  dimension(:),   intent(in), optional :: x_1D
    real(dp),                  dimension(:,:), intent(in), optional :: x_2D
    real(dp),     allocatable, dimension(:,:)                       :: evalDiffuseAmp

    if (present(x_1D)) then
       ! Input array is complete packed data vector
       
    else if (present(x_2D)) then
       ! Input array is alms(:,:)
       
    else
       ! Use internal array
       
    end if
    
  end function evalDiffuseAmp

  ! Evaluate amplitude map in brightness temperature at reference frequency
  function evalDiffuseMixmat(self, nside, nmaps, pix)
    class(comm_diffuse_comp),                intent(in)           :: self
    integer(i4b),                            intent(in)           :: nside, nmaps
    integer(i4b),              dimension(:), intent(in), optional :: pix
    real(dp),     allocatable, dimension(:,:)                     :: evalDiffuseMixmat
  end function evalDiffuseMixmat

  ! Generate simulated component
  function simDiffuseComp(self, handle, nside, nmaps, pix)
    class(comm_diffuse_comp),                intent(in)           :: self
    type(planck_rng),                        intent(inout)        :: handle
    integer(i4b),                            intent(in)           :: nside, nmaps
    integer(i4b),              dimension(:), intent(in), optional :: pix
    real(dp),     allocatable, dimension(:,:)                     :: simDiffuseComp
  end function simDiffuseComp
  
  ! Dump current sample to HDF chain files
  subroutine dumpDiffuseToHDF(self, filename)
    class(comm_diffuse_comp),                intent(in)           :: self
    character(len=*),                        intent(in)           :: filename
  end subroutine dumpDiffuseToHDF
  
  ! Dump current sample to HEALPix FITS file
  subroutine dumpDiffuseToFITS(self, dir)
    class(comm_diffuse_comp),                intent(in)           :: self
    character(len=*),                        intent(in)           :: dir
  end subroutine dumpDiffuseToFITS
  
end module comm_diffuse_comp_mod