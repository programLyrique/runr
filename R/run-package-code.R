#' Create a package environment with access to all package functions.
#' Based on testthat:::test_pkg_env.
#
#' @export
run_test_env <- function(package) {
  list2env(
    as.list(getNamespace(package), all.names=TRUE),
    parent=parent.env(getNamespace(package))
  )
}

#' Simpulate test_check ortherwise running test_dir might skip some tests.
#' Based on testthat:::test_package_dir.
#
#' @importFrom testthat test_dir
#' @importFrom withr local_options local_envvar
#' @export
run_test_dir <- function(package, path, ...) {
  env <- run_test_env(package)
  withr::local_options(list(topLevelEnvironment=env))
  withr::local_envvar(list(TESTTHAT_PKG=package, TESTTHAT_DIR=path))
  testthat::test_dir(path=path, env=env, ...)
}

#' on purpose it only uses base functions
#'
run_one <- function(package, file) {
  error <- as.character(NA)
  time <- as.double(NA)

  cat(
    "**********************************************************************\n",
    "*** PACKAGE ", package, " FILE ", file, "\n",
    "**********************************************************************\n",
    "\n",
    sep=""
  )

  output <- capture.output({
    tryCatch({
      dir <- dirname(file)
      # poor man's testthat detection
      if ((endsWith(tolower(file), "tests/testthat.r") ||
             endsWith(tolower(file), "tests/run-all.r")) &&
            dir.exists(file.path(dir, "testthat"))) {
        time <- system.time(
          run_test_dir(package, file.path(dir, "testthat"))
        )
      } else {
        time <- system.time(
          sys.source(
            file,
            envir=run_test_env(package),
            chdir=TRUE
          )
        )
      }
    }, error=function(e) {
      error <<- e$message
    })
  }, split=TRUE)

  if (is(time, "proc_time")) {
    time <- as.numeric(time["elapsed"])
  }

  output <- paste0(output, collapse="\n")

  data.frame(
    time=time,
    error=error,
    output=output,
    stringsAsFactors=FALSE,
    row.names=NULL
  )
}

#' on purpose it only uses base functions
#'
#' @export
run_all <- function(package, runnable_code_file, runnable_code_path=dirname(runnable_code_file)) {
  if (!file.exists(runnable_code_file)) {
    stop(runnable_code_file, ": no such runnable code file (wd=", getwd(), ")")
  }

  if (!dir.exists(runnable_code_path)) {
    stop(runnable_code_path, ": no such runnable code path (wd=", getwd(), ")")
  }
 
  files <- read.csv(runnable_code_file)

  rows <- apply(files, 1, function(x) {
    file <- file.path(runnable_code_path, x["path"])
    i <- data.frame(file=x["path"], type=x["type"], row.names=NULL, stringsAsFactors=FALSE)
    r <- run_one(package, file)
    cbind(i, r)
  })

  df <- if (length(rows) > 0) {
    do.call(rbind, rows)
  } else {
    data.frame(
      file=character(0),
      type=charactre(0),
      time=double(0),
      error=character(0),
      output=character(0),
      stringsAsFactors=FALSE,
      row.names=NULL
    )
  }

  df
}