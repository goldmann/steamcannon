// Make jQuery play nice with Rails respond_to format.js
$.ajaxSetup({
    'beforeSend': function(xhr) {
        xhr.setRequestHeader("Accept", "text/javascript");
    }
});

jQuery.fn.pulsate = function() {
    this.pulse({opacity: [1,.2]}, 500, 10);
};

jQuery.fn.applyOnce = function(marker_class) {
    if (!marker_class) {
        marker_class = 'ujs_rule_applied'
    }
    elements = this.filter(':not(.' + marker_class + ')')
    elements.addClass(marker_class)
    return elements
}

function update_instance_message(instance_id, message) {
    message_id = '#instance_' + instance_id + '_message'
    $(message_id + ' td').first().html(message)
    $(message_id).show()
}

function apply_ujs_rules($) {
    $('.details_toggle').applyOnce().click(function() {
        $($(this).attr('rel')).toggle()
        return false
    })

    $('.js-popup_dialog').applyOnce().each(function(idx, el) {
        $(el).jqm({trigger: $(el).attr('rel'), overlay:0})
    })


    $('#environment_form #environment_platform_version_id').applyOnce().change(function() {
        $('.content_row').hide()
        $('.row_for_platform_version_' + $(this).val() + '_cloud_profile_' + $('#environment_cloud_profile_id').val()).show()
    })

    $('#environment_form #environment_cloud_profile_id').applyOnce().change(function() {
        $('.content_row').hide()
        $('.row_for_platform_version_' + $('#environment_platform_version_id').val() + '_cloud_profile_' + $(this).val()).show()
    })

    //show the correct data on load
    $('#environment_form #environment_platform_version_id').trigger('change')

    /*
     * remove other, unused platform versions, since some versions of IE
     * will still submit form fields within hidden content.
     */
    $('body.environments_controller form').applyOnce().submit(function() {
        $('.content_row:hidden').remove()
    })

    $('body.cloud_profiles_controller form .js-password_toggle').applyOnce().click(function() {
        $("#password_field").slideToggle();
        $("#password_prompt").slideToggle();
    });

    $('#environment_images_container .image_row .start_another a').applyOnce().click(function() {
        $($(this).closest('.start_another').next('.start_another_dialog')).show();
    })

    $('#environment_images_container .image_row .start_another_dialog .close a').applyOnce().click(function() {
        $($(this).closest('.start_another_dialog')).hide();
    })


    $('#account_requests_index .js-state_display_toggle').applyOnce().click(function() {
        $('#account_requests_index').toggleClass($(this).attr('rel'))
        return false
    })

    $('#cloud_profile_form .js-verify_credential').applyOnce().change(function() {
        if ($('#cloud_profile_username').val() === '' &&
            $('#cloud_profile_password').val() === '') {
            return;
        }

        $('#cloud_profile_form').removeClass('credentials_valid credentials_invalid')
        $('#cloud_profile_form').addClass('verifying_credentials')

        get_with_cloud_credentials($('form').attr('action') + '/validate_cloud_credentials', function(data) {
            $('#cloud_profile_form').removeClass('verifying_credentials credentials_valid credentials_invalid')
            if (data.status == 'ok') {
                $('#cloud_profile_form').addClass('credentials_valid')
            } else {
                $('#cloud_profile_form').addClass('credentials_invalid')
            }
        })
    })

    $('#environment_form #environment_cloud_profile_id').applyOnce('ujs_update_cloud_settings_applied').change(function() {
        console.log($(this).val())
        if ($(this).val()) {
            $('#cloud_settings').addClass('loading')
            $.get('/cloud_profiles/' + $(this).val() + '/cloud_settings_block', function(data) {
                $('#cloud_settings').replaceWith(data)
            })
        }
    })
    
    $('.callout').applyOnce().delay(10000).slideUp()

    $("abbr.timeago").applyOnce().timeago()
}

jQuery(document).ready(function($) {
    $(document).ajaxStart(function() {
        $('#ajax-spinner').show()
    })

    $(document).ajaxStop(function() {
        $('#ajax-spinner').hide()
    })

    // apply ujs rules after each ajax request
    $(document).ajaxComplete(function() {
        apply_ujs_rules($)
    })

    // apply ujs rules on load
    apply_ujs_rules($)
})


function get_with_cloud_credentials(url, callback) {
    var params = 'username=' + encodeURIComponent($('#cloud_profile_username').val()) + '&password=' + encodeURIComponent($('#cloud_profile_password').val());
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

function remote_delete_volume(volume_name, url) {
    if (confirm("Are you sure you want to delete " + volume_name + "? Any data on it will be lost.")) {
        $.post(url, {_method: 'delete'}, function(data){
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

function update_volume_status(url, selector) {
    $.post(url, function(data) {
        $(selector).replaceWith(data.html);
    }, "json");
    setTimeout("update_volume_status('" + url + "', '" + selector + "')", 30000);
}

function monitor_volume(url, selector) {
    jQuery(document).ready(function($) {
        update_volume_status(url, selector);
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

function tail_event_log(url) {
    params = {range: parseInt($('table.event_tree tr:last').attr('id')) + 1}
    $.get(url, params, function(result) {
        $('table.event_tree').append(result)
        setTimeout("tail_event_log('" + url + "')", 30000)
    })
}


