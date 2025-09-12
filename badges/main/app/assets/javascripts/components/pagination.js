$(function() {
    if ($('#infinite-scrolling').size() > 0) {
        $('.pagination').hide();
        $('#load_more').on('click', function() {
           var more_posts_url;
            more_posts_url = $('.pagination .next_page a').attr('href');

            if (typeof more_posts_url !== "undefined") {
                $.getScript(more_posts_url);
                history.pushState(null, document.title, more_posts_url);
            }
        });
    }
});


