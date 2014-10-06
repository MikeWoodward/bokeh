define [
  "underscore"
  "common/logging"
  "common/svg_colors"
], (_, Logging, svg_colors) ->

  logger = Logging.logger

  class Properties
    source_v_select: (attrname, datasource) ->
      glyph_props = @
      # if the attribute is not on this property object at all, log a bad request
      if not (attrname of glyph_props)
        logger.warn("requested vector selection of unknown property '#{attrname}' on objects")
        return (null for i in datasource.get_length())

      prop = glyph_props[attrname]
      # if the attribute specifies a field, and the field exists on
      # the column source, return the column from the column source
      if prop.field? and (prop.field of datasource.get('data'))
        return datasource.get_column(prop.field)
      else
        # If the user gave an explicit value, that should always be returned
        if glyph_props[attrname].value?
          default_value = glyph_props[attrname].value

        # otherwise, if the attribute exists on the object, return that value.
        # (This is a convenience case for when the object passed in has a member
        # that has the same name as the glyphspec name, e.g. an actual field
        # named "x" or "radius".)

        else if (attrname of datasource.get('data'))
          return datasource.get_column(attrname)

        # finally, check for a default value on this property object that could be returned
        else if glyph_props[attrname].default?
          default_value = glyph_props[attrname].default

        #FIXME this is where we could return a generator, which might
        #do a better job for constant propagation
        #for some reason a list comprehension fails here
        retval = []
        for i in [0...datasource.get_length()]
          retval.push(default_value)
        return retval

    _fix_singleton_array_value: (obj) ->
      # XXX: this is required because we can't distinguish between
      # cases like Text(text="field") and Text(test="actual text").
      if obj.value?
        value = obj.value

        if _.isArray(value)
          if value.length == 1
            return _.extend({}, obj, {value: value[0]})
          else
            throw new Error("expected an array of length 1, got #{value}")

      return obj

    string: (styleprovider, attrname) ->
      @[attrname] = {}

      value = styleprovider.mget(attrname)
      if not value?
        null
      else if _.isString(value)
        @[attrname].value = value
      else if _.isObject(value)
        value = @_fix_singleton_array_value(value)
        @[attrname] = _.extend(@[attrname], value)
      else
        logger.warn("string property '#{attrname}' given invalid value: #{value}")

    boolean: (styleprovider, attrname) ->
      @[attrname] = {}

      value = styleprovider.mget(attrname)
      if not value?
        null
      else if _.isBoolean(value)
        @[attrname].value = value
      else if _.isString(value)
        @[attrname].field = value
      else if _.isObject(value)
        value = @_fix_singleton_array_value(value)
        @[attrname] = _.extend(@[attrname], value)
      else
        logger.warn("boolean property '#{attrname}' given invalid value: #{value}")

    number: (styleprovider, attrname) ->
      @[attrname] = {}

      units_value = styleprovider.mget(attrname + '_units') ? 'data'
      @[attrname].units = units_value

      value = styleprovider.mget(attrname)
      if not value?
        null
      else if _.isNumber(value)
        @[attrname].value = value
      else if _.isString(value)
        @[attrname].field = value
      else if _.isObject(value)
        value = @_fix_singleton_array_value(value)
        @[attrname] = _.extend(@[attrname], value)
      else
        logger.warn("number property '#{attrname}' given invalid value: #{value}")

    color: (styleprovider, attrname) ->
      @[attrname] = {}

      value = styleprovider.mget(attrname)
      if not value?
        null
      else if _.isString(value)
        if svg_colors[value]? or value.substring(0, 1) == "#"
          @[attrname].value = value
        else
          @[attrname].field = value
      else if _.isObject(value)
        value = @_fix_singleton_array_value(value)
        @[attrname] = _.extend(@[attrname], value)
      else
        logger.warn("color property '#{attrname}' given invalid value: #{value}")

    array: (styleprovider, attrname) ->
      @[attrname] = {}

      units_value = styleprovider.mget(attrname+"_units") ? 'data'
      @[attrname].units = units_value

      value = styleprovider.mget(attrname)
      if not value?
        null
      else if _.isString(value)
        @[attrname].field = value
      else if _.isArray(value)
        @[attrname].value = value
      else if _.isObject(value)
        value = @_fix_singleton_array_value(value)
        @[attrname] = _.extend(@[attrname], value)
      else
        logger.warn("array property '#{attrname}' given invalid value: #{value}")

    enum: (styleprovider, attrname, vals) ->
      @[attrname] = {}

      levels = vals.split(" ")
      default_value = styleprovider.mget(attrname)
      if not value?
        null
      else if _.isString(value)
        if value in levels
          @[attrname].value = value
        else
          @[attrname].field = value
      else if _.isObject(value)
        value = @_fix_singleton_array_value(value)
        @[attrname] = _.extend(@[attrname], value)
      else
        logger.warn("enum property '#{attrname}' given invalid value: #{value}")
        logger.warn(" - acceptable values:" + levels)

    setattr: (styleprovider, attrname, attrtype) ->
      values = null
      if attrtype.indexOf(":") > -1
        [attrtype, values] = attrtype.split(":")

      if      attrtype == "string"          then @string(styleprovider, attrname)
      else if attrtype == "boolean"         then @boolean(styleprovider, attrname)
      else if attrtype == "number"          then @number(styleprovider, attrname)
      else if attrtype == "color"           then @color(styleprovider, attrname)
      else if attrtype == "array"           then @array(styleprovider, attrname)
      else if attrtype == "enum" and values then @enum(styleprovider, attrname, values)
      else
        logger.warn("Unknown type '#{attrtype}' for glyph property: #{attrname}")

    select: (attrname, obj) ->
      # if the attribute is not on this property object at all, log a bad request
      if not (attrname of @)
        logger.warn("requested selection of unknown property '#{attrname}' on object: #{obj}")
        return

      # if the attribute specifies a field, and the field exists on the object, return that value
      if @[attrname].field? and (@[attrname].field of obj)
        return obj[@[attrname].field]

      # If the user gave an explicit value, that should always be returned
      if @[attrname].value?
        return @[attrname].value

      # Note about the following two checks. They are to accomodate the case where properties
      # are not used to map over data sources, but are used for one-off properties like a Plot
      # object might have. There is no corresponding check in v_select
      if obj.get and obj.get(attrname)
        return obj.get(attrname)

      if obj.mget and obj.mget(attrname)
        return obj.mget(attrname)

      # otherwise, if the attribute exists on the object, return that value.
      # (This is a convenience case for when the object passed in has a member
      # that has the same name as the glyphspec name, e.g. an actual field
      # named "x" or "radius".)
      if obj[attrname]?
        return obj[attrname]

      # finally, check for a default value on this property object that could be returned
      if @[attrname].default?
        return @[attrname].default

      # failing that, just log a problem
      logger.warn("selection for attribute '#{attrname}' failed on object: #{ obj }")

    v_select: (attrname, objs) ->

      # if the attribute is not on this property object at all, log a bad request
      if not (attrname of @)
        logger.warn("requested vector selection of unknown property '#{attrname}' on objects")
        return

      if @[attrname].typed?
        result = new Float64Array(objs.length)
      else
        result = new Array(objs.length)

      for i in [0...objs.length]

        obj = objs[i]

        # if the attribute specifies a field, and the field exists on the object, return that value
        if @[attrname].field? and (@[attrname].field of obj)
          result[i] = obj[@[attrname].field]

        # If the user gave an explicit value, that should always be returned
        else if @[attrname].value?
          result[i] = @[attrname].value

        # otherwise, if the attribute exists on the object, return that value
        else if obj[attrname]?
          result[i] = obj[attrname]

        # finally, check for a default value on this property object that could be returned
        else if @[attrname].default?
          result[i] = @[attrname].default

        # failing that, just log a problem
        else
          logger.warn("vector selection for attribute '#{attrname}' failed on object: #{obj}")
          return

      return result

  class LineProperties extends Properties
    constructor: (styleprovider, prefix="") ->
      @line_color_name        = "#{prefix}line_color"
      @line_width_name        = "#{prefix}line_width"
      @line_alpha_name        = "#{prefix}line_alpha"
      @line_join_name         = "#{prefix}line_join"
      @line_cap_name          = "#{prefix}line_cap"
      @line_dash_name         = "#{prefix}line_dash"
      @line_dash_offset_name  = "#{prefix}line_dash_offset"

      @color(styleprovider, @line_color_name)
      @number(styleprovider, @line_width_name)
      @number(styleprovider, @line_alpha_name)
      @enum(styleprovider, @line_join_name, "miter round bevel")
      @enum(styleprovider, @line_cap_name, "butt round square")
      @array(styleprovider, @line_dash_name)
      @number(styleprovider, @line_dash_offset_name)

      @do_stroke = true
      if not _.isUndefined(@[@line_color_name].value)
        if _.isNull(@[@line_color_name].value)
          @do_stroke = false
      else if _.isNull(@[@line_color_name].default)
        @do_stroke = false

    set: (ctx, obj) ->
      ctx.strokeStyle = @select(@line_color_name, obj)
      ctx.globalAlpha = @select(@line_alpha_name, obj)
      ctx.lineWidth   = @select(@line_width_name, obj)
      ctx.lineJoin    = @select(@line_join_name,  obj)
      ctx.lineCap     = @select(@line_cap_name,   obj)
      ctx.setLineDash(@select(@line_dash_name, obj))
      ctx.setLineDashOffset(@select(@line_dash_offset_name, obj))

    set_prop_cache: (datasource) ->
      @cache = {}
      @cache.strokeStyle       = @source_v_select(@line_color_name, datasource)
      @cache.globalAlpha       = @source_v_select(@line_alpha_name, datasource)
      @cache.lineWidth         = @source_v_select(@line_width_name, datasource)
      @cache.lineJoin          = @source_v_select(@line_join_name,  datasource)
      @cache.lineCap           = @source_v_select(@line_cap_name,   datasource)
      @cache.setLineDash       = @source_v_select(@line_dash_name,  datasource)
      @cache.setLineDashOffset = @source_v_select(@line_dash_offset_name, datasource)

    clear_prop_cache: () ->
      @cache = {}

    set_vectorize: (ctx, i) ->
      did_change = false
      if @cache.strokeStyle[i]? and ctx.strokeStyle != @cache.strokeStyle[i]
        ctx.strokeStyle = @cache.strokeStyle[i]
        did_change = true
      if @cache.globalAlpha[i]? and ctx.globalAlpha != @cache.globalAlpha[i]
        ctx.globalAlpha = @cache.globalAlpha[i]
        did_change = true
      if @cache.lineWidth[i]? and ctx.lineWidth != @cache.lineWidth[i]
        ctx.lineWidth = @cache.lineWidth[i]
        did_change = true
      if @cache.lineJoin[i]? and ctx.lineJoin != @cache.lineJoin[i]
        ctx.lineJoin = @cache.lineJoin[i]
        did_change = true
      if @cache.lineCap[i]? and ctx.lineCap != @cache.lineCap[i]
        ctx.lineCap = @cache.lineCap[i]
        did_change = true
      if @cache.setLineDash[i]? and ctx.getLineDash() != @cache.setLineDash[i]
        ctx.setLineDash(@cache.setLineDash[i])
        did_change = true
      if @cache.setLineDashOffset[i]? and \
          ctx.getLineDashOffset() != @cache.setLineDashOffset[i]
        ctx.setLineDashOffset(@cache.setLineDashOffset[i])
        did_change = true

      return did_change

  class FillProperties extends Properties
    constructor: (styleprovider, prefix="") ->
      @fill_color_name = "#{prefix}fill_color"
      @fill_alpha_name = "#{prefix}fill_alpha"

      @color(styleprovider, @fill_color_name)
      @number(styleprovider, @fill_alpha_name)

      @do_fill = true
      if not _.isUndefined(@[@fill_color_name].value)
        if _.isNull(@[@fill_color_name].value)
          @do_fill = false
      else if _.isNull(@[@fill_color_name].default)
        @do_fill = false

    set: (ctx, obj) ->
      ctx.fillStyle   = @select(@fill_color_name, obj)
      ctx.globalAlpha = @select(@fill_alpha_name, obj)

    set_prop_cache: (datasource) ->
      @cache = {}
      @cache.fillStyle         = @source_v_select(@fill_color_name, datasource)
      @cache.globalAlpha       = @source_v_select(@fill_alpha_name, datasource)

    set_vectorize: (ctx, i) ->
      did_change = false
      if ctx.fillStyle != @cache.fillStyle[i]
        ctx.fillStyle = @cache.fillStyle[i]
        did_change = true
      if ctx.globalAlpha != @cache.globalAlpha[i]
        ctx.globalAlpha = @cache.globalAlpha[i]
        did_change = true

      return did_change

  class TextProperties extends Properties
    constructor: (styleprovider, prefix="") ->
      @text_font_name       = "#{prefix}text_font"
      @text_font_size_name  = "#{prefix}text_font_size"
      @text_font_style_name = "#{prefix}text_font_style"
      @text_color_name      = "#{prefix}text_color"
      @text_alpha_name      = "#{prefix}text_alpha"
      @text_align_name      = "#{prefix}text_align"
      @text_baseline_name   = "#{prefix}text_baseline"

      @string(styleprovider, @text_font_name)
      @string(styleprovider, @text_font_size_name)
      @enum(styleprovider, @text_font_style_name, "normal italic bold")
      @color(styleprovider, @text_color_name)
      @number(styleprovider, @text_alpha_name)
      @enum(styleprovider, @text_align_name, "left right center")
      @enum(styleprovider, @text_baseline_name, "top middle bottom alphabetic hanging")

    font: (obj, font_size) ->
      if not font_size?
        font_size = @select(@text_font_size_name,  obj)
      font       = @select(@text_font_name,       obj)
      font_style = @select(@text_font_style_name, obj)
      font = font_style + " " + font_size + " " + font
      return font

    set: (ctx, obj) ->
      ctx.font         = @font(obj)
      ctx.fillStyle    = @select(@text_color_name,    obj)
      ctx.globalAlpha  = @select(@text_alpha_name,    obj)
      ctx.textAlign    = @select(@text_align_name,    obj)
      ctx.textBaseline = @select(@text_baseline_name, obj)

    set_prop_cache: (datasource) ->
      @cache = {}
      font_size    = @source_v_select(@text_font_size_name, datasource)
      font         = @source_v_select(@text_font_name, datasource)
      font_style   = @source_v_select(@text_font_style_name, datasource)
      @cache.font  = ( "#{font_style[i]} #{font_size[i]} #{font[i]}" for i in [0...font.length] )
      @cache.fillStyle    = @source_v_select(@text_color_name, datasource)
      @cache.globalAlpha  = @source_v_select(@text_alpha_name, datasource)
      @cache.textAlign    = @source_v_select(@text_align_name, datasource)
      @cache.textBaseline = @source_v_select(@text_baseline_name, datasource)

    clear_prop_cache: () ->
      @cache = {}

    set_vectorize: (ctx, i) ->
      did_change = false
      if ctx.font != @cache.font[i]
        ctx.font = @cache.font[i]
        did_change = true
      if ctx.fillStyle != @cache.fillStyle[i]
        ctx.fillStyle = @cache.fillStyle[i]
        did_change = true
      if ctx.globalAlpha != @cache.globalAlpha[i]
        ctx.globalAlpha = @cache.globalAlpha[i]
        did_change = true
      if ctx.textAlign != @cache.textAlign[i]
        ctx.textAlign = @cache.textAlign[i]
        did_change = true
      if ctx.textBaseline != @cache.textBaseline[i]
        ctx.textBaseline = @cache.textBaseline[i]
        did_change = true

      return did_change

  class GlyphProperties extends Properties
    constructor: (styleprovider, attrnames, properties) ->
      for attrname in attrnames
        attrtype = "number"
        if attrname.indexOf(":") > -1
          [attrname, attrtype] = attrname.split(":")
        @setattr(styleprovider, attrname, attrtype)

      for key of properties
        @[key] = properties[key]

  return {
    Glyph: GlyphProperties
    Fill: FillProperties
    Line: LineProperties
    Text: TextProperties
  }
