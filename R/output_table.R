#' Output Table
#'
#' Generates the output table for model and data
#' @param data A dataframe generated from the pre-processing step
#' @param model A model object used to classify ids with, generated from the model selection layer
#' @importFrom dplyr left_join select mutate group_by summarise summarise_each funs across
#' @importFrom rlang .data
#' @return A tibble providing high-level segment attributes such as mean and max (numeric) or mode (categorical)
#' for the segmentation features used.
#' @export
output_table <- function(data, model) {
  #TODO: Add summary stats for the predictors
  output <- data.frame(segment = model$predicted_values$segment,
                       id = as.character(model$predicted_values$id), 
                       stringsAsFactors = FALSE)
  if(!is.null(model$model_hyperparameters$dependent_variable)) {
    response <- model$model_hyperparameters$dependent_variable
  } else {
    response <- "response"
  }
  
  df <- left_join(data, output, by = 'id')
  
  
  segmentation_vars <- model$model_hyperparameters$segmentation_variables
  
  if(is.null(segmentation_vars)){
    allcolumnnames <- colnames(df)
    segmentation_vars <- allcolumnnames[!allcolumnnames %in% c('id', response , 'segment')]  
  }
  
  df_agg <- df %>% select(c('segment',model$model_hyperparameters$segmentation_variables)) 
  characterlevel <- lapply(df_agg,is.character)==TRUE
  
  df_agg_numeric <- df_agg[, unlist(lapply(df_agg, is.numeric)) | names(df_agg) == 'segment'] %>%
    group_by(.data$segment) %>%
    summarise(across(everything(), ~round(mean(.data$., na.rm = TRUE), 2)))
  
  df_agg_character <- df_agg[, !unlist(lapply(df_agg, is.numeric)) | names(df_agg) == 'segment'] %>%
    group_by(.data$segment) %>%
    summarise(across(everything(), ~mode(.data$.)))
  
  df_agg <- full_join(df_agg_numeric, df_agg_character, by = 'segment')
  
  names(df_agg)[characterlevel] <- paste0(names(df_agg)[characterlevel],'_mode')
  names(df_agg)[!characterlevel] <- paste0(names(df_agg)[!characterlevel],'_mean')
  names(df_agg)[1] <- 'segment'
  
  
  seg_vars <- model$model_hyperparameters$segmentation_variables
  df_agg2_numeric <- df[, (unlist(lapply(df, is.numeric)) & names(df) %in% seg_vars) | names(df) == 'segment'] %>%
    group_by(.data$segment) %>% 
    summarise(across(everything(), ~range_output(.data$.)))
  
  df_agg2_character <- df[, (!unlist(lapply(df, is.numeric)) & names(df) %in% seg_vars) | names(df) == 'segment'] %>%
    group_by(.data$segment) %>% 
    summarise(across(everything(), ~top5categories(.data$.)))
  
  df_agg2 <- full_join(df_agg2_numeric, df_agg2_character, by = 'segment')
  
  names(df_agg2)[characterlevel] <- paste0(names(df_agg2)[characterlevel],'_top5')
  names(df_agg2)[!characterlevel] <- paste0(names(df_agg2)[!characterlevel],'_range')
  names(df_agg2)[1] <- 'segment'
  
  df_agg <- df_agg %>% left_join(df_agg2, by = 'segment') 
  df_agg <- df_agg[,c(1,order(colnames(df_agg)[-1])+1)]
  
  if(response %in% names(df)) {
    df <- df %>%
      group_by(.data$segment)%>%
      summarise(n = n(), mean_value = mean(as.numeric(as.character(.data$response)),na.rm=TRUE)) %>%
      mutate(percentage = paste0(100*round((.data$n/sum(.data$n)),3),'%')) %>% 
        left_join(df_agg, by = 'segment')

  } else {
    df <- df %>%
      group_by(.data$segment)%>%
      summarise(n = n()) %>%
      mutate(mean_value = NULL, percentage = paste0(100*round(.data$n/sum(.data$n),3),'%')) %>% 
        left_join(df_agg, by = 'segment')
    
  }

  return(df)

}

top5categories <- function(codes){
  codes <- as.factor(codes)
  codes_table <- tabulate(codes)
  top5categories_input <- round(100*codes_table/sum(codes_table),2)
  top5categories_input_values <- top5categories_input[order(top5categories_input,decreasing = TRUE)[1:5]]
  top5categories_input_names <- levels(codes)[order(top5categories_input,decreasing = TRUE)[1:5]]
  top5categories_input_values <- top5categories_input_values[!is.na(top5categories_input_values)]
  top5categories_input_names <- top5categories_input_names[!is.na(top5categories_input_names)]
  top5categories_output <- paste0(top5categories_input_names, ' - ',top5categories_input_values,'%',collapse = '; ')
  return(top5categories_output)
}
  
mode <- function(codes, max = TRUE){
  codes <- as.factor(codes)
  if(max == TRUE){
    levels(codes)[which.max(tabulate(codes))]
  }else{
    levels(codes)[which.min(tabulate(codes))]
  }
}
range_output <- function(codes){
  min_codes <- round(min(codes,na.rm = TRUE),2)
  max_codes <- round(max(codes,na.rm = TRUE),2)
  output <- paste0(min_codes,' - ',max_codes)
  return(output)
}
