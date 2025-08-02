library(shiny)
library(igraph)

ui <- fluidPage(
  titlePanel("Regular Grammar to Automaton"),
  sidebarLayout(
    sidebarPanel(
      textAreaInput(
        inputId = "grammar",
        label = "Insert Regular Grammar:",
        value = paste(
          "S -> aA",
          "S -> bA",
          "A -> aB",
          "A -> bB",
          "A -> a",
          "B -> aA",
          "B -> bA",
          sep = "\n"
        ),
        rows = 10,
        width = "100%"
      )
    ),
    
    mainPanel(
      h5("Grammar Input:"),
      verbatimTextOutput("showText"),
      hr(),
      
      h5("States Graph:"),
      plotOutput("showPlot", height = "400px"),
      hr(),
      
      h5("Is it deterministic?"),
      verbatimTextOutput("showDeterministic")
    )
  )
)

# server logic
tu_server <- function(input, output) {
  # reactive: parse non-empty lines
  grammar_rules <- reactive({
    req(input$grammar)
    lines <- strsplit(input$grammar, "[\r\n]+")[[1]]
    trimws(lines[lines != ""])
  })
  
  # show input
  output$showText <- renderText({
    paste(grammar_rules(), collapse = "\n")
  })
  
  # show automaton
  output$showPlot <- renderPlot({
    rules <- grammar_rules()
    
    # extract LHS symbols
    lhs <- trimws(sapply(strsplit(rules, "->"), `[`, 1))
    # extract RHS symbols
    rhs <- trimws(sapply(strsplit(rules, "->"), `[`, 2))
    
    # build edge list
    edges <- do.call(rbind, lapply(seq_along(rhs), function(i) {
      symbols <- strsplit(rhs[i], "")[[1]]
      targets <- symbols[grepl("^[A-Z]$", symbols)]
      variables <- symbols[grepl("^[a-z]$", symbols)]
      if (length(targets) == 0) targets <- "Z"
      data.frame(
        from = lhs[i],
        to = targets,
        label = variables,
        stringsAsFactors = FALSE
      )
    }))
    
    # from Vertex to Vertex
    all_states <- unique(c(edges$from, edges$to))
    
    
    # create graph
    g <- graph_from_data_frame(edges, vertices = all_states, directed = TRUE)
    multiple <- which_multiple(g)
    E(g)$curved <- .2
    E(g)$curved[multiple] <- 1
    
    # create color conditions (wannabe-ternary)
    node_names <- V(g)$name
    node_colors <- ifelse( node_names == "S", "green",
      ifelse(node_names == "Z", "red",
             "lightblue"
      )
    )
    
    # plot nodes only
    plot(
      g,
      vertex.label = V(g)$name,
      vertex.color = node_colors,
      vertex.size = 30,
      vertex.label.cex = 1.3,
      
      edge.arrow.size = 0.5,
      edge.label = E(g)$label,
      edge.curved = E(g)$curved,
    )
  })
  
  # show deterministic
  output$showDeterministic <- renderText({
    rules <- grammar_rules()
    # extract LHS symbols
    lhs <- trimws(sapply(strsplit(rules, "->"), `[`, 1))
    # extract RHS symbols
    rhs <- trimws(sapply(strsplit(rules, "->"), `[`, 2))
    
    edges <- do.call(rbind, lapply(seq_along(rhs), function(i) {
      symbols <- strsplit(rhs[i], "")[[1]]
      targets <- symbols[grepl("^[A-Z]$", symbols)]
      variables <- symbols[grepl("^[a-z]$", symbols)]
      if (length(targets) == 0) targets <- "Z"
      data.frame(
        from = lhs[i],
        to = targets,
        label = variables,
        stringsAsFactors = FALSE
      )
    }))
    
    ### check if there is only one initial state
    
    # find all unique "from" and "to" states
    from_states <- unique(edges$from)
    to_states <- unique(edges$to)
    
    # remove Z from the list of to-states before checking
    to_states <- setdiff(to_states, "Z")
    
    # check if we are left with one initial
   initial_candidates <- setdiff(from_states, to_states)
    if (length(initial_candidates) == 1) {
      one_initial <- TRUE
    } else {
      one_initial <- FALSE
    }
    
    
    ### Check if each state has as many transitions as symbols
    
    # Get the full alphabet from the labels
    alphabet <- unique(edges$label)
    
    # Get all unique states that have outgoing transitions
    states <- unique(edges$from)
    
    # Check if each state has one transition for every symbol
    is_complete <- all(sapply(states, function(state) {
      symbols <- edges$label[edges$from == state]
      all(alphabet %in% symbols)
    }))
    
    # Check for duplicate (state, symbol) pairs — these are illegal in a DFA
    has_duplicates <- any(duplicated(edges[, c("from", "label")]))
    
    if (has_duplicates) {
      return("No, a state has more transitions than symbols")
    } else if (!is_complete) {
      return("No, a state is missing transitions")
    } else if (!one_initial) {
      return("No, there is more than an initial state")
    } else {
      return("Yes")
    }
    
    
  })
}

# Launch app
shinyApp(ui = ui, server = tu_server)