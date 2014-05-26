math = mathjs()
diff = diffjs(math)

jQuery ($) ->
    $("#button").click (event) ->
        event.preventDefault()
        value =  $("#input").val()
        new_value =
            try diff.parse(value).diff().optimize().expr.toString()
            catch error then error
        $("#output").text new_value
            
