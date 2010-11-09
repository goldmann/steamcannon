// Make jQuery play nice with Rails respond_to format.js
$.ajaxSetup({
    'beforeSend': function(xhr) {
        xhr.setRequestHeader("Accept", "text/javascript");
    }
});

jQuery.fn.pulsate = function() {
    this.pulse({opacity: [1,.2]}, 500, 10);
};

function update_instance_message(instance_id, message) {
    message_id = '#instance_' + instance_id + '_message'
     $(message_id + ' td').first().html(message)
    $(message_id).show()
}


function apply_unobtrusive_rules($) {
    $('.js-popup_dialog').each(function(idx, el) {
        $(el).jqm({trigger: $(el).attr('rel'), overlay:0})
    })


    $('#environment_form #environment_platform_version_id').change(function() {
        $('.content_row').hide()
        $('.row_for_platform_version_' + this.value).show()
    })

    //show the correct data on load
    $('#environment_form #environment_platform_version_id').trigger('change')

    /*
     * remove other, unused platform versions, since some versions of IE
     * will still submit form fields within hidden content.
     */
    $('body.environments_controller form').submit(function() {
        $('.content_row:hidden').remove()
    })

    $('body.users_controller form .js-cloud_password_toggle').click(function() {
        $("#cloud_password_field").slideToggle();
        $("#cloud_password_prompt").slideToggle();
    });

    $('#environment_images_container .image_row .start_another a').click(function() {
        $($(this).closest('.start_another').next('.start_another_dialog')).show();
    })

    $('#environment_images_container .image_row .start_another_dialog .close a').click(function() {
        $($(this).closest('.start_another_dialog')).hide();
    })


    $('#account_requests_index .js-state_display_toggle').click(function() {
        $('#account_requests_index').toggleClass($(this).attr('rel'))
        return false
    })

    $('#edit_user .js-verify_credential').change(function() {
        if ($('#user_cloud_username').val() === '' ||
            $('#user_cloud_password').val() === '') {
            return
        }

        $('#edit_user').removeClass('credentials_valid credentials_invalid')
        $('#edit_user').addClass('verifying_credentials')

        get_with_cloud_credentials('/account/validate_cloud_credentials', function(data) {
            $('#edit_user').removeClass('verifying_credentials credentials_valid credentials_invalid')
            if (data.status == 'ok') {
                $('#edit_user').addClass('credentials_valid')
                load_account_cloud_defaults()
            } else {
                $('#edit_user').addClass('credentials_invalid')
            }
        })
    })

}

jQuery(document).ready(function($) {
    $(document).ajaxStart(function() {
        $('#ajax-spinner').show()
    })

    $(document).ajaxStop(function() {
        $('#ajax-spinner').hide()
    })

    $(document).ajaxComplete(function() {
        apply_unobtrusive_rules($)
    })

    $('.callout').delay(10000).slideUp()

    apply_unobtrusive_rules($)
})


function get_with_cloud_credentials(url, callback) {
    params = 'cloud_username=' + encodeURIComponent($('#user_cloud_username').val()) + '&cloud_password=' + encodeURIComponent($('#user_cloud_password').val())
    $.get(url + '?' + params, callback);
}

function load_account_cloud_defaults() {
    get_with_cloud_credentials('/account/cloud_defaults_block', function(data) {
        elem = $('#cloud_defaults')
        if (elem.html() != data) {
            elem.html(data);
        }
    })
}

function remote_stop_instance(instance_name, url) {
    if (confirm("Are you sure you want to stop " + instance_name + "?")) {
        $.post(url, function(data){
            if (data.js) {
                eval(data.js)
            }
            alert(data.message)
        }, "json");
    }
}

function update_deployment_status(url, selector) {
  $.post(url, function(data) {
      $(selector + ' .status ul').replaceWith(data)
  });
  setTimeout("update_deployment_status('" + url + "', '" + selector + "')", 30000);
}

function monitor_deployment(url, selector) {
  jQuery(document).ready(function($) {
    update_deployment_status(url, selector);
  });
}

function update_content(url, selectors) {
    $.get(url, function(data) {
        $(selectors.split('|')).each(function(index, selector) {
            if ('#' + $(data).attr('id') == selector) {
                content = $(data)
            } else {
                content = $(data).find(selector)
            }
            $(selector).html(content.html())
        })
    })

    setTimeout("update_content('" + url + "', '" + selectors + "')", 30000);
}

function monitor_content(url, selectors) {
  $(function () {
      update_content(url, selectors.join('|'));
  });
}

function update_instance_status(url, selector) {
  $.post(url, function(data) {
      $(selector).replaceWith(data.html);
  }, "json");
  setTimeout("update_instance_status('" + url + "', '" + selector + "')", 30000);
}

function monitor_instance(url, selector) {
  jQuery(document).ready(function($) {
    update_instance_status(url, selector);
  });
}

function tail_log(url, num_lines, offset, tailing) {
  var params = {num_lines: num_lines, offset: offset};
  $.get(url, params, function(data) {
    logs = $('#log_output');
    if (logs.text().trim() == 'Fetching log...') {
      logs.html('');
    }
    if (data.lines.length > 0) {
      //logs.html(logs.html() + "<br />" + data.lines.join("<br />"));
      //logs.html(logs.html() + "\n" + data.lines.join("\n"));
      logs.html(logs.html() + data.lines.join(""));
      if (tailing) {
        logs.animate({scrollTop: logs.attr("scrollHeight")}, 10);
      }
    }
    if (tailing || data.lines.length > 0) {
      setTimeout("tail_log('" + url + "', " + num_lines + ", " + data.offset + ", + " + tailing + ")", 5000);
    }
  }, "json");
}


