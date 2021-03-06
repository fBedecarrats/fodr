#' fetch dataset attachments
#'
#' This method is used to retrieve attachments from a  dataset.
#'
#' @param fname a character, the title of the file in the \code{attachments} element of the \code{info} field
#' @param output a character, the destination file name, if NULL (the default) it will be the same as \code{fname}
#' 
#' @name get_attachments
#' @examples 
#' \donttest{
#' horodateurs <- fodr_dataset("paris", "horodateurs-transactions-de-paiement")
#' horodateurs$get_attachments(fname = "NOTICE_horodateurs.pdf")
#' }
NULL
