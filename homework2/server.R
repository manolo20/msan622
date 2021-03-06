library(shiny)
library(ggplot2)
library(scales)
library(grid)
library(RColorBrewer)

# Munging
data(movies)
movies <- subset(movies, budget > 0)
genre <- rep(NA, nrow(movies))
count <- rowSums(movies[, 18:24])
genre[which(count > 1)] = "Mixed"
genre[which(count < 1)] = "None"
genre[which(count == 1 & movies$Action == 1)] = "Action"
genre[which(count == 1 & movies$Animation == 1)] = "Animation"
genre[which(count == 1 & movies$Comedy == 1)] = "Comedy"
genre[which(count == 1 & movies$Drama == 1)] = "Drama"
genre[which(count == 1 & movies$Documentary == 1)] = "Documentary"
genre[which(count == 1 & movies$Romance == 1)] = "Romance"
genre[which(count == 1 & movies$Short == 1)] = "Short"
movies$genre <- factor(genre)

# Themeing  
logspace <- function( d1, d2, n) exp(log(10)*seq(d1, d2, length.out=n))
support <- logspace(0,8,9)
custom <- theme(text = element_text(size = 16, colour = "gray"), 
                axis.text.x = element_text(colour = "gray"), 
                axis.text.y = element_text(colour = "gray"),
                axis.ticks = element_line(colour = 'gray'),
                
                title = element_text(vjust = 2),
                axis.title.x = element_text(vjust = -1.25), 
                axis.title.y = element_text(vjust = -0.1),
                
                plot.background = element_blank(),
                plot.margin = unit(c(1, 1, 1, 1), "cm"),
                
                panel.background = element_blank(),
                panel.grid = element_blank(),
                
                line = element_line(colour = 'gray'),
                axis.line = element_line(colour = 'gray'),
                legend.position = 'right',
                legend.title = element_blank(),
                legend.background = element_blank(),
                legend.key = element_blank())

shinyServer(function(input, output) {
  
  local.movies <- movies
  mpaas <- levels(local.movies$mpaa)[levels(local.movies$mpaa) != '']
  genres <- levels(local.movies$genre)
  
  # Build rating UI element
  output$mpaa <- renderUI({
    radioButtons('mpaa', 'MPAA Rating',
                 choices = c('All', mpaas),
                 selected = 'All')
  })
  
  # Build genre UI element
  output$genres <- renderUI({
    checkboxGroupInput('genres', 'Genres', 
                       choices  = genres,
                       selected = genres)
  })
  
  # Adjust dataset based on UI inputs
  getdata <- reactive({
    
    # Selection logic
    if (input$mpaa != 'All' & length(input$genres) != 0) {
      dataset <- subset(local.movies,
                        mpaa == input$mpaa & genre %in% input$genres)
      inactive <- subset(local.movies,
                         mpaa != input$mpaa | ! genre %in% input$genres)
    } else if (input$mpaa != 'All') {
      dataset <- subset(local.movies,
                        mpaa == input$mpaa)
      inactive <- subset(local.movies,
                         mpaa != input$mpaa)
    } else if (length(input$genres) != 0) {
      dataset <- subset(local.movies, 
                        genre %in% input$genres)
      inactive <- subset(local.movies,
                         ! genre %in% input$genres)
    } else {
      dataset <- local.movies
      inactive <- data.frame()
    }  
    
    # Return the active and inactive partitions of the data
    current <- list(dataset, inactive)
    names(current) <- c('dataset', 'inactive')
    return(current)
  })
  
  # Plot!
  output$plot <- renderPlot({
    
    # Wait for UI controls to set
    if(is.null(input$mpaa)) {
      return()
    }
    
    color <- c(brewer.pal(length(levels(local.movies$genre)), input$color_scheme), "#FFFFFF")
    names(color) <- levels(local.movies$genre)
    
    # Adjust color
    color <- c(brewer.pal(length(levels(local.movies$genre)), input$color_scheme), "#FFFFFF")
    names(color) <- levels(local.movies$genre)
    
    # Get the data
    inactive <- getdata()[['inactive']]
    active <- getdata()[['dataset']]

    # Plot inactive data, if any    
    if (nrow(inactive) > 0) {
      p <- ggplot(data = inactive,
                  aes(x = budget, 
                      y = rating),
                  colour = 'grey') + 
        geom_point(alpha = .05,
                   size = 1 + (input$dot_size /3))
    } else {
      p <- ggplot()
    }
    
    # Plot active data, if any
    if (nrow(active) > 0 ) {
    p <- p + geom_point(data = active,
                        alpha = input$dot_alpha,
                        size = 1 + (input$dot_size / 3),
                        aes(x = budget,
                            y = rating,
                            colour = genre)) +
      guides(colour = guide_legend(override.aes = list(shape = 15,
                                                       size = 10)))
    }
    
    # Add remaining plot layers, regardless of data 
    p <- p +
        scale_x_log10(breaks=support,
                      labels=dollar(support),
                      limits=c(min(local.movies$budget, na.rm = T),
                               max(local.movies$budget, na.rm = T))) +
        scale_y_continuous(breaks=0:10,
                           expand=c(0,0),
                           limits=c(0,10.5)) +
        scale_colour_manual(values=color) +
        annotation_logticks(sides='b',
                            colour = 'gray') +
        xlab('Budget') + ylab('Average Rating') +
        custom
    
    print(p)
    
  }, bg = 'transparent')
  
  # Include the selected raw data
  output$table <- renderDataTable({
    getdata()[['dataset']][,-7:-24]}, 
    options = list(sPaginationType = "two_button",
                   sScrollY = "400px",
                   bScrollCollapse = 'true'))
  
})