$(function() {
  setActiveMenuItem();
    $('.js-accordion-trigger').bind('click', function(e){
       showSubMenu($(this));
       e.preventDefault();
    });
});

$(document).ready(function() {
    $('i.fa-bars').bind('click', function() {
        $('#sidebar').collapse('toggle');
    });

    $('#sidebar').bind('show.bs.collapse', function() {
        $(this).removeClass('sidebar-mobile');
    })
});


function showSubMenu($this) {
  var submenu;

  if($this && $this.hasClass('js-my-group-trigger')) {
      submenu = $('.js-side-nav-submenu.js-my-group');
      $('.js-my-group-trigger').find("i").last().toggleClass('icon-arrow-down icon-arrow-up');
   } else if($this && $this.hasClass('js-report-trigger')) {
      submenu = $('.js-side-nav-submenu.js-report');
       $('.js-report-trigger').find("i").last().toggleClass('icon-arrow-down icon-arrow-up');
  } else {
    submenu = $('.js-side-nav-submenu.js-quick-links')
  }

  submenu.slideToggle('fast');
  submenu.toggleClass('is-expanded');
}

function setActiveMenuItem() {
  var link;
  var path = window.location.pathname;
  switch (path) {
    case '/resources':
      if (window.location.href.includes('Scholarship')) {
        link = $('.js-scholarships');
      } else {
        link = $('.js-resources');
      }
      break;
    case '/resources/search':
      link = $('.js-resources');
      break;
    case '/resources/' + digit(path):
      link = $('.js-resources');
      break;
    case '/resources/new':
      link = $('.js-story')
      showSubMenu();
      break;
    case '/workshops':
      link = $('.js-search');
      break;
    case '/workshops/' + digit(path):
      link = $('.js-search');
      break;
    case '/workshops/search':
      link = $('.js-search');
      break;
    case '/workshops/new':
    case '/workshop_logs/new':
      subMenu = $('.js-report');
      showSubMenu(subMenu);
      link = $('.js-add-workshop-log');
      break;

      case '/reports/monthly':
      case '/reports/monthly_select_type':
       subMenu = $('.js-report');
       showSubMenu(subMenu);
       link = $('.js-add-montly-report');
      break;
      case '/reports/annual':
       subMenu = $('.js-report');
       showSubMenu(subMenu);
       link = $('.js-add-annual-report');
       break;

    case '/workshop_log_creation_wizard/fill_out_form':
      link = $('.js-new-report');
      showSubMenu();
      break;
    case '/workshop_log_creation_wizard/confirmation':
      link = $('.js-new-report');
      showSubMenu();
      break;
    case '/workshop_log_creation_wizard/choose_method':
      link = $('.js-new-report');
      showSubMenu();
      break;
    case '/reports/share_story':
        link = $('.js-story');
      showSubMenu();
      break;
    case '/workshops/share_idea':
      link = $('.js-new-workshop');
      showSubMenu();
      break;
    case '/workshops/' + digit(path) + '/edit':
      link = $('.js-new-workshop');
      showSubMenu();
      break;
    case '/bookmarks':
      link = $('.js-bookmarks');
      break;
    case '/bookmarks/' + digit(path):
      link = $('.js-bookmarks');
      break;
    case '/contact_us':
      link = $('.js-contact');
      break;
    case '/faqs':
      link = $('.js-faq');
      showSubMenu();
      break;
    case '/users/new':
      subMenu = $('.js-my-group');
      showSubMenu(subMenu);
      link = $('.js-add-leader')
      break;
    case '/users/' + digit(path):
      submenu = $('.js-my-group');
      showSubMenu(submenu);
      link = $('#js-user-' + digit(path)[0]);
      break;
    default:
      link = $('.js-dashboard');
  }
  link.addClass('active');
}

function digit(path) {
  return path.match(/\d+/g);
}
