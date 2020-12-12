toHTML <- function(x, standalone = FALSE, knitrOptions = NULL) {
  
  sizeInfo <- resolveSizing(x, x$sizingPolicy, standalone = standalone, knitrOptions = knitrOptions)
  
  if (!is.null(x$elementId))
    id <- x$elementId
  else
    id <- paste("htmlwidget", createWidgetId(), sep="-")
  
  w <- validateCssUnit(sizeInfo$width)
  h <- validateCssUnit(sizeInfo$height)
  
  # create a style attribute for the width and height
  style <- paste(
    "width:", w, ";",
    "height:", h, ";",
    sep = "")
  
  x$id <- id
  
  container <- if (isTRUE(standalone)) {
    function(x) {
      div(id="htmlwidget_container", x)
    }
  } else {
    identity
  }
  
  html <- htmltools::tagList(
    container(
      htmltools::tagList(
        x$prepend,
        widget_html(
          name = class(x)[1],
          package = attr(x, "package"),
          id = id,
          style = style,
          class = paste(class(x)[1], "html-widget"),
          width = sizeInfo$width,
          height = sizeInfo$height
        ),
        x$append
      )
    ),
    widget_data(x, id),
    if (!is.null(sizeInfo$runtime)) {
      tags$script(type="application/htmlwidget-sizing", `data-for` = id,
                  toJSON(sizeInfo$runtime)
      )
    }
  )
  html <- htmltools::attachDependencies(html,
                                        c(widget_dependencies(class(x)[1], attr(x, 'package')),
                                          x$dependencies)
  )
  
  htmltools::browsable(html)
  
}

lookup_func <- function(name, package) {
  tryCatch(
    get(name, asNamespace(package), inherits = FALSE),
    error = function(e) NULL
  )
}

# since the normal saveWidget isn't working, manually remove pandoc_available line
saveWidget_fixed <- function(widget, file, selfcontained = TRUE, libdir = NULL,
                             background = "white", title = class(widget)[[1]],
                             knitrOptions = list()) {
  
  # Transform #RRGGBB/#RRGGBBAA colors to rgba(r,g,b,a) form, because the
  # pound sign interferes with pandoc processing
  if (grepl("^#", background, perl = TRUE)) {
    bgcol <- grDevices::col2rgb(background, alpha = TRUE)
    background <- sprintf("rgba(%d,%d,%d,%f)", bgcol[1,1], bgcol[2,1], bgcol[3,1], bgcol[4,1]/255)
  }
  
  # convert to HTML tags
  html <- toHTML(widget, standalone = TRUE, knitrOptions = knitrOptions)
  
  # form a path for dependenent files
  if (is.null(libdir)){
    libdir <- paste(tools::file_path_sans_ext(basename(file)), "_files",
                    sep = "")
  }
  
  # make it self-contained if requested
  if (selfcontained) {
    
    # Save the file
    # Include a title; pandoc 2.0 complains if you don't have one
    pandoc_save_markdown(html, file = file, libdir = libdir,
                         background = background, title = title)
    
    # if (!pandoc_available()) {
    #   stop("Saving a widget with selfcontained = TRUE requires pandoc. For details see:\n",
    #        "https://github.com/rstudio/rmarkdown/blob/master/PANDOC.md")
    # }
    
    pandoc_self_contained_html(file, file)
    unlink(libdir, recursive = TRUE)
  } else {
    # no pandoc needed if not selfcontained
    html <- tagList(tags$head(tags$title(title)), html)
    htmltools::save_html(html, file = file, libdir = libdir, background = background)
  }
  
  invisible(NULL)
}


  
save(saveWidget_fixed,toHTML_fixed,file="saveWidget.Rdata")