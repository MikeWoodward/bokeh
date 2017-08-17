{% extends "autoload_js.js" %}

{% block register_mimetype %}

  var MIME_TYPE = 'application/vnd.bokehjs_exec.v0+json';
  var CLASS_NAME = 'output_bokeh rendered_html';

  /**
   * Render data to the DOM node
   */
  function render(props, node) {
    var div = document.createElement("div");
    div.innerHTML = props["data"]["div"];
    var script = document.createElement("script");
    script.textContent = props["data"]["script"];

    node.appendChild(div);
    node.appendChild(script);
  }

  /**
   * Handle when an output is cleared or removed
   */
  function handleClearOutput(event, { cell: { output_area } }) {
    /* Get rendered DOM node */
    var id = output_area._bokeh_element_id
    var bk_element = Bokeh.index[id]
    bk_element.remove()
    delete Bokeh.index[id]

    var toinsert = output_area.element.find(CLASS_NAME.split(' ')[0]);
    /* e.g. Dispose of resources used by renderer library */
    // if (toinsert) renderLibrary.dispose(toinsert[0]);
  }

  /**
   * Handle when a new output is added
   */
  function handleAddOutput(event,  { output, output_area }) {
    // store reference to embedded id on output_area
    output_area._bokeh_element_id = output.metadata[MIME_TYPE]["id"]

    /* Get rendered DOM node */
    var toinsert = output_area.element.find(CLASS_NAME.split(' ')[0]);
    /** e.g. Inject a static image representation into the mime bundle for
     *  endering on Github, etc.
     */
    // if (toinsert) {
    //   renderLibrary.toPng(toinsert[0]).then(url => {
    //     const data = url.split(',')[1];
    //     output_area.outputs
    //       .filter(output => output.data[MIME_TYPE])
    //       .forEach(output => {
    //         output.data['image/png'] = data;
    //       });
    //   });
    // }
  }

  function register_renderer(notebook, OutputArea) {

    // get OutputArea instance
    var code_cell = notebook.get_cells().reduce(function(result, cell) { return cell.output_area ? cell : result })
    var output_area = code_cell.output_area

    // function to render output of bk mime renderer
    function append_mime(data, metadata, element) {
      // create a DOM node to render to
      var toinsert = this.create_output_subarea(
        metadata,
        CLASS_NAME,
        MIME_TYPE
      );
      this.keyboard_manager.register_events(toinsert);
      // Render to node
      var props = {data, metadata: metadata[MIME_TYPE]}
      render(props, toinsert[0])
      element.append(toinsert)
      return toinsert;
    }

    /* Handle when an output is cleared or removed */
    output_area.events.on('clear_output.CodeCell', handleClearOutput);
    output_area.events.on('delete.Cell', handleClearOutput);

    /* Handle when a new output is added */
    output_area.events.on('output_added.OutputArea', handleAddOutput);

    // renderer priority
    /* ...or just insert it at the top */
    var index = 0;

    /**
     * Register the mime type and append_mime function with output_area
     */
    OutputArea.prototype.register_mime_type(MIME_TYPE, append_mime, {
      /* Is output safe? */
      safe: true,
      /* Index of renderer in `output_area.display_order` */
      index: index
    });
  }

  // do the thing
  var OutputArea = root.Jupyter.OutputArea
  if ((root.Jupyter !== undefined) && (!OutputArea.prototype.mime_types().includes(MIME_TYPE))) {
    register_renderer(root.Jupyter.notebook, OutputArea)
  }

{% endblock %}

{% block autoload_init %}
  if (typeof (root._bokeh_timeout) === "undefined" || force === true) {
    root._bokeh_timeout = Date.now() + {{ timeout|default(0)|json }};
    root._bokeh_failed_load = false;
  }

  var NB_LOAD_WARNING = {'data': {'text/html':
     "<div style='background-color: #fdd'>\n"+
     "<p>\n"+
     "BokehJS does not appear to have successfully loaded. If loading BokehJS from CDN, this \n"+
     "may be due to a slow or bad network connection. Possible fixes:\n"+
     "</p>\n"+
     "<ul>\n"+
     "<li>re-rerun `output_notebook()` to attempt to load from CDN again, or</li>\n"+
     "<li>use INLINE resources instead, as so:</li>\n"+
     "</ul>\n"+
     "<code>\n"+
     "from bokeh.resources import INLINE\n"+
     "output_notebook(resources=INLINE)\n"+
     "</code>\n"+
     "</div>"}};

  function display_loaded() {
    if (root.Bokeh !== undefined) {
      var el = document.getElementById({{ elementid|json }});
      el.textContent = "BokehJS " + Bokeh.version + " successfully loaded.";
    } else if (Date.now() < root._bokeh_timeout) {
      setTimeout(display_loaded, 100)
    }
  }

  {%- if comms_target -%}
  if ((root.Jupyter !== undefined) && Jupyter.notebook.kernel) {
    comm_manager = Jupyter.notebook.kernel.comm_manager
    comm_manager.register_target({{ comms_target|json }}, function () {});
  }
  {%- endif -%}
{% endblock %}

{% block run_inline_js %}
    if ((root.Bokeh !== undefined) || (force === true)) {
      for (var i = 0; i < inline_js.length; i++) {
        inline_js[i].call(root, root.Bokeh);
      }
      {%- if elementid -%}
      if (force === true) {
        display_loaded();
      }
      {%- endif -%}
    } else if (Date.now() < root._bokeh_timeout) {
      setTimeout(run_inline_js, 100);
    } else if (!root._bokeh_failed_load) {
      console.log("Bokeh: BokehJS failed to load within specified timeout.");
      root._bokeh_failed_load = true;
    } else if (force !== true) {
      var cell = $(document.getElementById({{ elementid|json }})).parents('.cell').data().cell;
      cell.output_area.append_execute_result(NB_LOAD_WARNING)
    }
{% endblock %}
