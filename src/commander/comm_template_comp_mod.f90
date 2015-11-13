module comm_template_comp_mod
  use comm_param_mod
  use comm_comp_mod
  use comm_map_mod
  implicit none

  private
  public comm_template_comp

  type Tnu
     logical(lgt) :: fullsky
     integer(i4b) :: nside, np, nmaps, band
     integer(i4b), allocatable, dimension(:,:) :: pix   ! Pixel list, both in map and absolute order
     real(dp),     allocatable, dimension(:,:) :: map   ! (0:np-1,nmaps)
     real(dp),     allocatable, dimension(:)   :: f     ! Frequency scaling (nmaps)
  end type Tnu
  
  !**************************************************
  !            Template class
  !**************************************************
  type, abstract, extends (comm_comp) :: comm_template_comp
     character(len=512) :: outprefix
     real(dp),     allocatable, dimension(:)   :: x     ! Amplitude (nmaps)
     real(dp),     allocatable, dimension(:,:) :: theta ! Spectral parameters (npar,nmaps)
     type(Tnu),    allocatable, dimension(:)   :: T     ! Spatial template (nband)
   contains
     procedure :: dumpFITS => dumpTemplateToFITS
     procedure :: getBand  => evalTemplateBand
     procedure :: projectBand  => projectTemplateBand
  end type comm_template_comp

contains

  function evalTemplateBand(self, band, amp_in, pix)
    implicit none
    class(comm_template_comp),                    intent(in)            :: self
    integer(i4b),                                 intent(in)            :: band
    integer(i4b),    dimension(:),   allocatable, intent(out), optional :: pix
    real(dp),        dimension(:,:),              intent(in),  optional :: amp_in
    real(dp),        dimension(:,:), allocatable                        :: evalTemplateBand

    evalTemplateBand = 0.d0

  end function evalTemplateBand
  
  ! Return component projected from map
  function projectTemplateBand(self, band, map)
    implicit none
    class(comm_template_comp),                    intent(in)            :: self
    integer(i4b),                                 intent(in)            :: band
    class(comm_map),                              intent(in)            :: map
    real(dp),        dimension(:,:), allocatable                        :: projectTemplateBand

    projectTemplateBand = 0.d0
  end function projectTemplateBand
  
  ! Dump current sample to HEALPix FITS file
  subroutine dumpTemplateToFITS(self, postfix, dir)
    implicit none
    character(len=*),                        intent(in)           :: postfix
    class(comm_template_comp),               intent(in)           :: self
    character(len=*),                        intent(in)           :: dir

    integer(i4b)       :: i
    character(len=512) :: filename
    
  end subroutine dumpTemplateToFITS
  
end module comm_template_comp_mod
