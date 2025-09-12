var form   = $('.edit_workshop');
var navbar = $('.navbar');

// listen for `invalid` events on all form inputs
function scroll_here(input_field) {
        var input = $(input_field);
        input.css("border", "1px solid red");

        // height of the nav bar plus some padding
        var navbarHeight = navbar.height() + 120;

        // the position to scroll to (accounting for the navbar)
        var elementOffset = input.offset().top - navbarHeight;

        // the current scroll position (accounting for the navbar)
        var pageOffset = window.pageYOffset - navbarHeight;

        // don't scroll if the element is already in view
        if (elementOffset > pageOffset && elementOffset < pageOffset + window.innerHeight) {
            return true;
        }

        $('html, body').scrollTop(elementOffset);
}

