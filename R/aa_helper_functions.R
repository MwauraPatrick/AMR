# ==================================================================== #
# TITLE                                                                #
# Antimicrobial Resistance (AMR) Analysis                              #
#                                                                      #
# SOURCE                                                               #
# https://gitlab.com/msberends/AMR                                     #
#                                                                      #
# LICENCE                                                              #
# (c) 2018-2020 Berends MS, Luz CF et al.                              #
#                                                                      #
# This R package is free software; you can freely use and distribute   #
# it for both personal and commercial purposes under the terms of the  #
# GNU General Public License version 2.0 (GNU GPL-2), as published by  #
# the Free Software Foundation.                                        #
#                                                                      #
# We created this package for both routine data analysis and academic  #
# research and it was publicly released in the hope that it will be    #
# useful, but it comes WITHOUT ANY WARRANTY OR LIABILITY.              #
# Visit our website for more info: https://msberends.gitlab.io/AMR.    #
# ==================================================================== #

# No export, no Rd
addin_insert_in <- function() {
  rstudioapi::insertText(" %in% ")
}

# No export, no Rd
addin_insert_like <- function() {
  rstudioapi::insertText(" %like% ")
}

check_dataset_integrity <- function() {
  tryCatch({
    check_microorganisms <- all(c("mo", "fullname", "kingdom", "phylum",
                                  "class", "order", "family", "genus", 
                                  "species", "subspecies", "rank",
                                  "col_id", "species_id", "source",
                                  "ref", "prevalence", "snomed") %in% colnames(microorganisms),
                                na.rm = TRUE) & NROW(microorganisms) == NROW(microorganismsDT)
    check_antibiotics <- all(c("ab", "atc", "cid", "name", "group", 
                               "atc_group1", "atc_group2", "abbreviations",
                               "synonyms", "oral_ddd", "oral_units", 
                               "iv_ddd", "iv_units", "loinc") %in% colnames(antibiotics),
                             na.rm = TRUE)
  }, error = function(e)
    stop('Please use the command \'library("AMR")\' before using this function, to load the required reference data.', call. = FALSE)
  )
  if (!check_microorganisms | !check_antibiotics) {
    stop("Data set `microorganisms` or data set `antibiotics` is overwritten by your global environment and prevents the AMR package from working correctly. Please rename your object before using this function.", call. = FALSE)
  }
  invisible(TRUE)
}

#' @importFrom crayon blue bold red
#' @importFrom dplyr %>% pull
search_type_in_df <- function(x, type) {
  # try to find columns based on type
  found <- NULL

  colnames(x) <- trimws(colnames(x))
  
  # -- mo
  if (type == "mo") {
    if ("mo" %in% lapply(x, class)) {
      found <- colnames(x)[lapply(x, class) == "mo"][1]
    } else if ("mo" %in% colnames(x) &
               suppressWarnings(
                 all(x$mo %in% c(NA,
                                 microorganisms$mo,
                                 microorganisms.translation$mo_old)))) {
      found <- "mo"
    } else if (any(colnames(x) %like% "^(mo|microorganism|organism|bacteria|bacterie)s?$")) {
      found <- colnames(x)[colnames(x) %like% "^(mo|microorganism|organism|bacteria|bacterie)s?$"][1]
    } else if (any(colnames(x) %like% "^(microorganism|organism|bacteria|bacterie)")) {
      found <- colnames(x)[colnames(x) %like% "^(microorganism|organism|bacteria|bacterie)"][1]
    } else if (any(colnames(x) %like% "species")) {
      found <- colnames(x)[colnames(x) %like% "species"][1]
    }
    
  }
  # -- key antibiotics
  if (type == "keyantibiotics") {
    if (any(colnames(x) %like% "^key.*(ab|antibiotics)")) {
      found <- colnames(x)[colnames(x) %like% "^key.*(ab|antibiotics)"][1]
    }
  }
  # -- date
  if (type == "date") {
    if (any(colnames(x) %like% "^(specimen date|specimen_date|spec_date)")) {
      # WHONET support
      found <- colnames(x)[colnames(x) %like% "^(specimen date|specimen_date|spec_date)"][1]
      if (!any(class(x %>% pull(found)) %in% c("Date", "POSIXct"))) {
        stop(red(paste0("ERROR: Found column `", bold(found), "` to be used as input for `col_", type,
                        "`, but this column contains no valid dates. Transform its values to valid dates first.")),
             call. = FALSE)
      }
    } else {
      for (i in seq_len(ncol(x))) {
        if (any(class(x %>% pull(i)) %in% c("Date", "POSIXct"))) {
          found <- colnames(x)[i]
          break
        }
      }
    }
  }
  # -- patient id
  if (type == "patient_id") {
    if (any(colnames(x) %like% "^(identification |patient|patid)")) {
      found <- colnames(x)[colnames(x) %like% "^(identification |patient|patid)"][1]
    }
  }
  # -- specimen
  if (type == "specimen") {
    if (any(colnames(x) %like% "(specimen type|spec_type)")) {
      found <- colnames(x)[colnames(x) %like% "(specimen type|spec_type)"][1]
    } else if (any(colnames(x) %like% "^(specimen)")) {
      found <- colnames(x)[colnames(x) %like% "^(specimen)"][1]
    }
  }
  # -- UTI (urinary tract infection)
  if (type == "uti") {
    if (any(colnames(x) == "uti")) {
      found <- colnames(x)[colnames(x) == "uti"][1]
    } else if (any(colnames(x) %like% "(urine|urinary)")) {
      found <- colnames(x)[colnames(x) %like% "(urine|urinary)"][1]
    }
    if (!is.null(found)) {
      # this column should contain logicals
      if (!is.logical(x[, found, drop = TRUE])) {
        message(red(paste0("NOTE: Column `", bold(found), "` found as input for `col_", type,
                           "`, but this column does not contain 'logical' values (TRUE/FALSE) and was ignored.")))
        found <- NULL
      }
    }
  }
  
  if (!is.null(found)) {
    msg <- paste0("NOTE: Using column `", bold(found), "` as input for `col_", type, "`.")
    if (type %in% c("keyantibiotics", "specimen")) {
      msg <- paste(msg, "Use", bold(paste0("col_", type), "= FALSE"), "to prevent this.")
    }
    message(blue(msg))
  }
  found
}

stopifnot_installed_package <- function(package) {
  # no "utils::installed.packages()" since it requires non-staged install since R 3.6.0
  # https://developer.r-project.org/Blog/public/2019/02/14/staged-install/index.html
  tryCatch(get(".packageName", envir = asNamespace(package)),
           error = function(e) stop("package '", package, "' required but not installed",
                                    ' - try to install it with: install.packages("', package, '")',
                                    call. = FALSE))
  return(invisible())
}

stopifnot_msg <- function(expr, msg) {
  if (!isTRUE(expr)) {
    stop(msg, call. = FALSE)
  }
}


"%or%" <- function(x, y) {
  if (is.null(x) | is.null(y)) {
    if (is.null(x)) {
      return(y)
    } else {
      return(x)
    }
  }
  ifelse(!is.na(x),
         x,
         ifelse(!is.na(y), y, NA))
}

class_integrity_check <- function(value, type, check_vector) {
  if (!all(value[!is.na(value)] %in% check_vector)) {
    warning(paste0("invalid ", type, ", NA generated"), call. = FALSE)
    value[!value %in% check_vector] <- NA
  }
  value
}

# transforms data set to data.frame with only ASCII values, to comply with CRAN policies
dataset_UTF8_to_ASCII <- function(df) {
  trans <- function(vect) {
    iconv(vect, from = "UTF-8", to = "ASCII//TRANSLIT")
  }
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  for (i in seq_len(NCOL(df))) {
    col <- df[, i]
    if (is.list(col)) {
      col <- lapply(col, function(j) trans(j))
      df[, i] <- list(col)
    } else {
      if (is.factor(col)) {
        levels(col) <- trans(levels(col))
      } else if (is.character(col)) {
        col <- trans(col)
      } else {
        col
      }
      df[, i] <- col
    }
  }
  df
}