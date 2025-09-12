$(document).on("click", "#password-confirmation-container, #new-password-container", function(e){
  target = $(e.currentTarget)
  passwordField = $(target).parents(".password-container").find(".password-field")
  type = $(passwordField).attr("type")
  if (type === "password") {
    $(passwordField).attr("type", "text")
    $(target).find("i").removeClass("fa-eye-slash");
    $(target).find("i").addClass("fa-eye");
  } else {
    $(passwordField).attr("type", "password")
    $(target).find("i").removeClass("fa-eye");
    $(target).find("i").addClass("fa-eye-slash");
  }
})