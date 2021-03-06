module comm_F_int_mod
  use comm_utils
  implicit none

  private
  public comm_F_int, F_int_ptr
  
  type, abstract :: comm_F_int
   contains
     ! Data procedures
     procedure(evalIntF),   deferred :: eval
  end type comm_F_int

  abstract interface
     ! Evaluate SED in brightness temperature normalized to reference frequency
     function evalIntF(self, theta)
       import comm_F_int, dp
       class(comm_F_int),                intent(in) :: self
       real(dp),          dimension(1:), intent(in) :: theta
       real(dp)                                     :: evalIntF
     end function evalIntF
  end interface

  type F_int_ptr
     class(comm_F_int), pointer :: p
  end type F_int_ptr
  
end module comm_F_int_mod
