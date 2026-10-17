//= require active_admin/base

document.addEventListener("DOMContentLoaded", function () {
  var search = document.getElementById("website_x_account_search");
  var select = document.getElementById("website_x_account_id");
  if (!search || !select) return;

  var options = Array.from(select.options);
  search.addEventListener("input", function () {
    var query = search.value.trim().toLocaleLowerCase();
    var selectedValue = select.value;
    select.replaceChildren();
    options.forEach(function (option) {
      if (!option.value || option.value === selectedValue || option.text.toLocaleLowerCase().includes(query)) {
        select.appendChild(option);
      }
    });
    select.value = selectedValue;
  });
});
