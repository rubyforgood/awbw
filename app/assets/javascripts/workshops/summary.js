// I'm sorry for this code... I didn't write it, I only moved it

$.urlParam = function(name) {
  var results = new RegExp("[?&]" + name + "=([^&#]*)").exec(
    window.location.href
  );
  if (results == null) return null;
  else return results[1] || 0;
};

function fillOutDates() {
  var months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
  ];

  var select = document.getElementById("report_date");
  var d = new Date();
  var current_month = d.getMonth();
  var current_year = d.getFullYear();
  for (var i = 0; i <= 12 * 2; i++) {
    var opt = document.createElement("option");
    if (current_month < 0) {
      current_month = 11;
      current_year -= 1;
    }
    opt.value = current_year + "-" + (current_month + 1);
    opt.innerHTML = months[current_month] + " " + current_year;
    if (
      parseInt($.urlParam("month")) - 1 == current_month &&
      parseInt($.urlParam("year")) == current_year
    ) {
      opt.selected = true;
    }
    if (select) select.appendChild(opt);
    current_month -= 1;
  }
  if (select)
    select.addEventListener("change", function() {
      var date = select.options[select.selectedIndex].value;
      var year = date.split("-")[0];
      var month = date.split("-")[1];
      window.location =
        window.location.toString().split("?month=")[0] +
        "?month=" +
        month +
        "&year=" +
        year;
    });
}

fillOutDates();

var enable_submit_form = false;

$("form").submit(function(event) {
  if (!enable_submit_form) {
    event.preventDefault();
  }
});
