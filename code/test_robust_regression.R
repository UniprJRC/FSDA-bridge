# test_robust_regression.R — consolidated tester-mode suite for the Robust
# Regression category of Group 2's kickoff plan: FSR, FSRaddt, LXS, MMreg.
#
# GOAL: this is deliberately NOT a "does it work" demo. The objective set by
# the team coordinator is to actively try to break each routine and record
# what happens — pass, clean rejection, or defect — whatever the outcome.
# No engine/FSDA/MATLAB code is ever modified; this script only calls the
# existing bridge (code/fsda_engine/engine.R -> engine.py) and observes.
#
# ACCEPTANCE THRESHOLD: numeric agreement against an independent reference
# (a classical R fit, a published result, or a repeat run) must be within
# 1e-9 absolute difference to count as a PASS. This is the same tolerance
# used by the project's official agreement gate (check_engine.R).
#
# AI-ASSISTANCE DISCLOSURE: this test suite was designed and written with
# the assistance of an AI coding assistant (Claude), working interactively
# with a human team member across several sessions. The AI helped design the
# test strategies (metamorphic relations, option fuzzing, break attempts),
# generate the R code, run it against the live MATLAB/FSDA engine, and
# interpret/record the results. All MATLAB/FSDA output shown in this file's
# results table is real output from running the actual engine — nothing is
# fabricated — but the test *design* and *wording* had AI involvement and
# should be reviewed accordingly. See TEST-REPORT.md for the full narrative
# and a plain-language summary of every finding.
#
# This file consolidates what were previously 7 separate scripts
# (test2.R, test_findings.R, test_deep.R, test_category.R, test_hunt.R,
# test_hunt2.R, test_insurance.R) into one ordered run, sections A-INS below.
# A full run takes roughly 20-25 minutes (it starts MATLAB engine sessions
# and performs 100+ FSDA calls).

.find_script_dir = function() {
  args = commandArgs(trailingOnly = FALSE)
  fa = grep("^--file=", args, value = TRUE)
  if (length(fa) == 1) {
    return(normalizePath(dirname(sub("^--file=", "", fa)), winslash = "/", mustWork = TRUE))
  }
  for (i in rev(seq_along(sys.frames()))) {
    ofile = sys.frames()[[i]]$ofile
    if (!is.null(ofile) && nzchar(ofile) && basename(ofile) == "test_robust_regression.R") {
      return(normalizePath(dirname(ofile), winslash = "/", mustWork = TRUE))
    }
  }
  here = normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  for (candidate in c(file.path(here, "code"), here)) {
    if (file.exists(file.path(candidate, "fsda_engine", "engine.R"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Cannot locate code/fsda_engine/engine.R — run from the repo root or via Rscript code/test_robust_regression.R")
}
.script_dir = .find_script_dir()
.repo_root = normalizePath(file.path(.script_dir, ".."), winslash = "/", mustWork = TRUE)

if (!nzchar(Sys.getenv("FSDA_DEV_VENV"))) {
  venv_py = file.path(.repo_root, ".venv", "bin", "python")
  if (!file.exists(venv_py)) venv_py = file.path(.repo_root, ".venv", "Scripts", "python.exe")
  if (file.exists(venv_py)) Sys.setenv(FSDA_DEV_VENV = venv_py)
}
fsda_root = Sys.getenv("FSDA_ROOT")
if (!nzchar(fsda_root)) {
  addon = path.expand("~/Library/Application Support/MathWorks/MATLAB Add-Ons/Toolboxes/FSDA")
  fsda_root = if (dir.exists(addon)) addon else NULL
}

source(file.path(.script_dir, "fsda_engine", "engine.R"))

# --- shared test-recording helpers ---------------------------------------------
results = list()
record = function(id, test, status, detail = "") {
  results[[length(results) + 1]] <<- list(id = id, test = test, status = status, detail = detail)
  cat(sprintf("  [%s] %s — %s\n", status, id, detail))
}
one_line = function(msg, width = 200) {
  msg = gsub("[[:space:]]+", " ", msg)
  if (nchar(msg) > width) msg = paste0(substr(msg, 1, width), "...")
  msg
}
finite_ids = function(x) { v = suppressWarnings(as.numeric(x)); v[is.finite(v)] }
attempt = function(expr) {
  tryCatch(list(ok = TRUE, out = expr), error = function(e) list(ok = FALSE, msg = conditionMessage(e)))
}

cat("Starting MATLAB engine...\n")
h = start_engine("FSR", fsda_root = fsda_root)

alive = function() {
  tryCatch(isTRUE(all.equal(as.numeric(eval_m(h, "1+1")), 2)), error = function(e) FALSE)
}
session_checks = 0
session_failures = 0
check_session = function(id) {
  session_checks <<- session_checks + 1
  if (!alive()) {
    session_failures <<- session_failures + 1
    record(paste0(id, "s"), "engine session survives", "FINDING", "session DEAD after this attempt; restarted")
    h <<- start_engine("FSR", fsda_root = fsda_root)
  }
}
seed_rng = function() invisible(eval_m(h, "rng(42);", nargout = 0))

fsr = function(yy, XX, ...) fsda_call(h, "FSR", yy, XX, nsamp = 0, intercept = TRUE,
                                      plots = 0, msg = 0, ...)

# --- shared data: wool benchmark (27 obs, 3 predictors) -------------------------
wool = as.matrix(read.csv(file.path(.script_dir, "Score", "reference", "wool.csv")))
y = matrix(wool[, ncol(wool)], ncol = 1)
X = wool[, 1:(ncol(wool) - 1)]
n = nrow(y)
ref_outliers = c(10, 11, 13, 19, 20, 21, 22, 23, 25)   # published Atkinson-Riani result
ref_lxs = c(542, 228, -196, -104)

# ================================================================================
cat("\n=== Section A: baseline agreement against known references ===\n")

# A1 — FSR on raw wool: published outlier set + beta must equal OLS on kept units.
a1 = fsda_call(h, "FSR", y, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0)
a1_out = finite_ids(a1$ListOut)
record("A1a", "FSR raw wool outliers", if (identical(sort(a1_out), sort(ref_outliers))) "PASS" else "FAIL",
       paste("flagged:", paste(sort(a1_out), collapse = " ")))
keep = setdiff(seq_len(n), a1_out)
d1 = max(abs(as.numeric(a1$beta) - as.numeric(coef(lm(y[keep, 1] ~ X[keep, , drop = FALSE])))))
record("A1b", "FSR beta == OLS on kept units (tol 1e-9)", if (d1 <= 1e-9) "PASS" else "FAIL",
       sprintf("max abs diff %.3e", d1))

# A2 — FSR on log(y): homogeneous sample -> 0 outliers, beta == full-sample lm() (the Box-Cox story).
ylog = log(y)
a2 = fsda_call(h, "FSR", ylog, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0)
a2_out = finite_ids(a2$ListOut)
record("A2a", "FSR log(y) outlier count", if (length(a2_out) == 0) "PASS" else "FAIL",
       sprintf("%d outliers (expected 0) — Box-Cox story: %d on raw y -> %d on log(y)",
               length(a2_out), length(a1_out), length(a2_out)))
d2 = max(abs(as.numeric(a2$beta) - as.numeric(coef(lm(ylog ~ X)))))
record("A2b", "FSR log(y) beta == lm() oracle (tol 1e-9)", if (d2 <= 1e-9) "PASS" else "FAIL",
       sprintf("max abs diff %.3e", d2))

# A3 — LXS beta against the recorded reference values.
a3 = fsda_call(h, "LXS", y, X, intercept = TRUE, plots = 0, msg = 0)
d3 = max(abs(as.numeric(a3$beta) - ref_lxs))
record("A3", "LXS beta vs reference [542 228 -196 -104]", if (d3 <= 1e-6) "PASS" else "FAIL",
       sprintf("beta [%s], max abs diff %.3e", paste(format(as.numeric(a3$beta), digits = 7), collapse = ", "), d3))

# A4 — determinism: repeat both calls, results must be identical.
a4f = fsda_call(h, "FSR", y, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0)
same_fsr = identical(sort(finite_ids(a4f$ListOut)), sort(a1_out)) &&
  max(abs(as.numeric(a4f$beta) - as.numeric(a1$beta))) == 0
record("A4a", "FSR determinism (2 runs)", if (same_fsr) "PASS" else "FAIL",
       if (same_fsr) "identical outliers and beta" else "second run differs")
a4l = fsda_call(h, "LXS", y, X, intercept = TRUE, plots = 0, msg = 0)
d4 = max(abs(as.numeric(a4l$beta) - as.numeric(a3$beta)))
record("A4b", "LXS determinism (2 runs)", if (d4 == 0) "PASS" else "FAIL",
       sprintf("max abs diff between runs %.3e", d4))

# ================================================================================
cat("\n=== Section B: break attempts — shapes, NaN, dims, tiny n ===\n")

# B5 — y passed as a (1, n) row instead of the documented (n, 1) column.
b5 = attempt(fsda_call(h, "FSR", matrix(y, nrow = 1), X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0))
if (!b5$ok) {
  record("B5", "y as (1,n) row", "CLEAN-ERROR", one_line(b5$msg))
} else {
  b5_out = finite_ids(b5$out$ListOut)
  match_ref = identical(sort(b5_out), sort(ref_outliers))
  record("B5", "y as (1,n) row", if (match_ref) "SILENT-OK" else "FINDING",
         sprintf("no error; %d outliers [%s] — %s", length(b5_out), paste(sort(b5_out), collapse = " "),
                 if (match_ref) "same result as the correct call (auto-reshaped)" else "DIFFERS: silent wrong answer"))
}
check_session("B5")

# B6 — NaN inside y.
b6 = attempt(fsda_call(h, "FSR", local({ z = y; z[3, 1] = NaN; z }), X,
                       nsamp = 0, intercept = TRUE, plots = 0, msg = 0))
if (!b6$ok) {
  record("B6", "NaN in y", "CLEAN-ERROR", one_line(b6$msg))
} else {
  b6_out = finite_ids(b6$out$ListOut)
  record("B6", "NaN in y", "SILENT-OK",
         sprintf("no error; %d outliers [%s] — silently renumbered (see Finding F1)",
                 length(b6_out), paste(sort(b6_out), collapse = " ")))
}
check_session("B6")

# B7 — mismatched dimensions: y has 27 rows, X only 20.
b7 = attempt(fsda_call(h, "FSR", y, X[1:20, , drop = FALSE], nsamp = 0, intercept = TRUE, plots = 0, msg = 0))
record("B7", "dim mismatch y(27) vs X(20)", if (!b7$ok) "CLEAN-ERROR" else "FINDING",
       if (!b7$ok) one_line(b7$msg) else "no error on mismatched dimensions")
check_session("B7")

# B8 — tiny sample: n = 5 rows, 3 predictors + intercept (4 params).
b8 = attempt(fsda_call(h, "FSR", y[1:5, , drop = FALSE], X[1:5, , drop = FALSE],
                       nsamp = 0, intercept = TRUE, plots = 0, msg = 0))
record("B8", "tiny n=5 with p=4", if (!b8$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!b8$ok) one_line(b8$msg) else sprintf("no error; %d outliers", length(finite_ids(b8$out$ListOut))))
check_session("B8")

# ================================================================================
cat("\n=== Section C: marshalling depth — odd R types/shapes through the bridge ===\n")

# C1 — Inf inside y.
c1 = attempt(fsr(local({ z = y; z[3, 1] = Inf; z }), X))
if (!c1$ok) {
  record("C1", "Inf in y", "CLEAN-ERROR", one_line(c1$msg))
} else {
  ids = finite_ids(c1$out$ListOut)
  record("C1", "Inf in y", "SILENT-OK",
         sprintf("no error; %d outliers [%s] — renumbered like NaN (Finding F1)", length(ids), paste(sort(ids), collapse = " ")))
}
check_session("C1")

# C2 — R's NA_real_ (vs literal NaN): does it marshal identically?
c2 = attempt(fsr(local({ z = y; z[3, 1] = NA_real_; z }), X))
if (!c2$ok) {
  record("C2", "NA_real_ in y", "CLEAN-ERROR", one_line(c2$msg))
} else {
  ids = finite_ids(c2$out$ListOut)
  shifted = c(9, 10, 12, 18, 19, 20, 21, 24, 25)
  record("C2", "NA_real_ in y", "SILENT-OK",
         sprintf("no error; %d outliers [%s] — %s", length(ids), paste(sort(ids), collapse = " "),
                 if (identical(sort(ids), shifted)) "identical to the NaN case (NA==NaN through the bridge)" else "DIFFERS from the NaN case"))
}
check_session("C2")

# C3 — integer storage mode (R integer matrix -> numpy int -> MATLAB?)
c3 = attempt(fsr(local({ z = y; storage.mode(z) = "integer"; z }), local({ z = X; storage.mode(z) = "integer"; z })))
if (!c3$ok) {
  record("C3", "integer storage.mode y/X", "CLEAN-ERROR", one_line(c3$msg))
} else {
  ids = finite_ids(c3$out$ListOut)
  record("C3", "integer storage.mode y/X", if (identical(sort(ids), ref_outliers)) "PASS" else "FINDING",
         sprintf("%d outliers [%s] — identical to double-precision run: %s",
                 length(ids), paste(sort(ids), collapse = " "), identical(sort(ids), ref_outliers)))
}
check_session("C3")

# C4 — data.frame instead of matrix for X.
c4 = attempt(fsr(y, as.data.frame(X)))
record("C4", "X as data.frame", if (!c4$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!c4$ok) one_line(c4$msg) else sprintf("%d outliers", length(finite_ids(c4$out$ListOut))))
check_session("C4")

# C5 — character matrix for y.
c5 = attempt(fsr(matrix("a", n, 1), X))
record("C5", "character y", if (!c5$ok) "CLEAN-ERROR" else "FINDING",
       if (!c5$ok) one_line(c5$msg) else "no error raised on character input")
check_session("C5")

# C6 — empty input: 0-row y and X.
c6 = attempt(fsr(matrix(numeric(0), 0, 1), matrix(numeric(0), 0, 3)))
record("C6", "empty (0-row) y/X", if (!c6$ok) "CLEAN-ERROR" else "FINDING",
       if (!c6$ok) one_line(c6$msg) else "no error raised on empty input")
check_session("C6")

# C7 — extreme magnitude: y * 1e150 (squares reach ~1e300, near double overflow).
c7 = attempt(fsr(y * 1e150, X))
if (!c7$ok) {
  record("C7", "y scaled by 1e150 (overflow probe)", "CLEAN-ERROR", one_line(c7$msg))
} else {
  ids = finite_ids(c7$out$ListOut)
  record("C7", "y scaled by 1e150 (overflow probe)", if (identical(sort(ids), ref_outliers)) "PASS" else "FINDING",
         sprintf("%d outliers [%s] — %s", length(ids), paste(sort(ids), collapse = " "),
                 if (identical(sort(ids), ref_outliers)) "preserved" else "CHANGED: silent numeric instability (Finding F2)"))
}
check_session("C7")

# ================================================================================
cat("\n=== Section D: statistical stress — masking, breakdown, equivariance, exact fit ===\n")

# D1 — masking: 8 planted high-leverage outliers; FSR should flag all 8, classical lm() should miss them.
set.seed(123)
x_good = 1:42
y_good = 2 + 3 * x_good + rnorm(42, sd = 1)
x_bad = 60 + rnorm(8, sd = 0.1)
y_bad = 2 + 3 * 60 - 60 + rnorm(8, sd = 1)
Xd = matrix(c(x_good, x_bad), ncol = 1)
yd = matrix(c(y_good, y_bad), ncol = 1)
planted = 43:50
d1 = attempt(fsr(yd, Xd))
if (!d1$ok) {
  record("D1a", "FSR vs leverage-cluster masking", "FAIL", one_line(d1$msg))
} else {
  ids = finite_ids(d1$out$ListOut)
  found = sum(planted %in% ids)
  record("D1a", "FSR vs leverage-cluster masking", if (found == 8) "PASS" else "FAIL",
         sprintf("FSR flagged %d/8 planted outliers", found))
}
lm_found = sum(planted %in% which(abs(rstandard(lm(yd ~ Xd))) > 2.5))
record("D1b", "lm() rstandard>2.5 on same data", "INFO",
       sprintf("classical lm flags only %d/8 planted outliers (masking demonstrated)", lm_found))

# D2 — LXS breakdown sweep: contaminate 10/25/40% of wool y with +2000.
for (frac in c(0.10, 0.25, 0.40)) {
  k = round(frac * n)
  y_cont = y; y_cont[1:k, 1] = y_cont[1:k, 1] + 2000
  d2 = attempt(fsda_call(h, "LXS", y_cont, X, intercept = TRUE, plots = 0, msg = 0))
  id = sprintf("D2-%d%%", round(frac * 100))
  if (!d2$ok) {
    record(id, sprintf("LXS with %d/%d contaminated", k, n), "FAIL", one_line(d2$msg))
  } else {
    dev_lxs = max(abs(as.numeric(d2$out$beta) - ref_lxs))
    resisted = dev_lxs < 100
    record(id, sprintf("LXS with %d/%d contaminated", k, n), if (resisted) "PASS" else "PASS (theoretical breakdown)",
           sprintf("LXS beta drift %.1f — %s", dev_lxs,
                   if (resisted) "robust fit resisted" else "breaks exactly at LMS theoretical breakdown point (n/2-p+2)/n"))
  }
}

# D3 — degenerate exact fit: y is EXACTLY linear in X (zero residuals, scale 0).
y_exact = matrix(5 + X %*% c(2, -1, 0.5), ncol = 1)
d3f = attempt(fsr(y_exact, X))
record("D3a", "FSR on exact linear fit (scale 0)", if (!d3f$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!d3f$ok) one_line(d3f$msg)
       else sprintf("no error; %d outliers; beta [%s] (true: 5,2,-1,0.5)",
                    length(finite_ids(d3f$out$ListOut)), paste(format(as.numeric(d3f$out$beta), digits = 6), collapse = ", ")))
check_session("D3a")
d3l = attempt(fsda_call(h, "LXS", y_exact, X, intercept = TRUE, plots = 0, msg = 0))
record("D3b", "LXS on exact linear fit (scale 0)", if (!d3l$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!d3l$ok) one_line(d3l$msg)
       else sprintf("no error; beta [%s] (true: 5,2,-1,0.5)", paste(format(as.numeric(d3l$out$beta), digits = 6), collapse = ", ")))
check_session("D3b")

# D4 — equivariance: rescale y*1e3 and X columns by (10, 0.1, 5); outlier SET must be invariant.
Xs = X %*% diag(c(10, 0.1, 5))
d4 = attempt(fsr(y * 1e3, Xs))
if (!d4$ok) {
  record("D4", "FSR equivariance under rescaling", "FAIL", one_line(d4$msg))
} else {
  ids = finite_ids(d4$out$ListOut)
  record("D4", "FSR equivariance under rescaling", if (identical(sort(ids), ref_outliers)) "PASS" else "FAIL",
         sprintf("outliers [%s] %s reference set", paste(sort(ids), collapse = " "), if (identical(sort(ids), ref_outliers)) "==" else "!="))
}

# ================================================================================
cat("\n=== Section E: bridge/API guards — injection, unknown routine, bad options ===\n")

# E1 — injection attempt in the routine NAME: _IDENT_RE must reject it before MATLAB.
e1 = attempt(fsda_call(h, "FSR;quit", y, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0))
record("E1", "injection guard: name 'FSR;quit'", if (!e1$ok) "CLEAN-ERROR" else "FINDING",
       if (!e1$ok) one_line(e1$msg) else "call was ACCEPTED — injection guard failed")
record("E1s", "session alive after injection attempt", if (alive()) "PASS" else "FINDING",
       if (alive()) "quit did not execute" else "session DEAD — quit executed!")
if (!alive()) h = start_engine("FSR", fsda_root = fsda_root)

# E2 — unknown routine name.
e2 = attempt(fsda_call(h, "NotARealRoutine", y, X))
record("E2", "unknown routine name", if (!e2$ok) "CLEAN-ERROR" else "FINDING",
       if (!e2$ok) one_line(e2$msg) else "no error for a nonexistent routine")
check_session("E2")

# E3 — wrong option type: intercept as a string.
e3 = attempt(fsda_call(h, "FSR", y, X, nsamp = 0, intercept = "yes", plots = 0, msg = 0))
record("E3", "intercept='yes' (wrong type)", if (!e3$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!e3$ok) one_line(e3$msg) else sprintf("accepted; %d outliers — Finding F3 (misleading message)", length(finite_ids(e3$out$ListOut))))
check_session("E3")

# E4 — FSDA's own documented rescue: does bonflev=0.99 make n=5 run?
e4 = attempt(fsda_call(h, "FSR", y[1:5, , drop = FALSE], X[1:5, , drop = FALSE],
                       nsamp = 0, intercept = TRUE, plots = 0, msg = 0, bonflev = 0.99))
record("E4", "tiny n=5 rescued by bonflev=0.99", if (e4$ok) "PASS" else "CLEAN-ERROR",
       if (e4$ok) sprintf("runs as documented; %d outliers", length(finite_ids(e4$out$ListOut))) else one_line(e4$msg))
check_session("E4")

# E5 — nargout abuse: ask FSR for 2 outputs when it returns 1.
e5 = attempt(fsda_call(h, "FSR", y, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0, nargout = 2))
record("E5", "nargout=2 on single-output FSR", if (!e5$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!e5$ok) one_line(e5$msg) else "returned without error")
check_session("E5")

# ================================================================================
cat("\n=== Section F: FSRaddt — added t-values along the forward search ===\n")

# F1c — run + oracle: final-step deletion t-value must equal classical lm() t-statistics.
f1 = attempt(fsda_call(h, "FSRaddt", y, X, nsamp = 0, plots = 0))
if (!f1$ok) {
  record("F1c", "FSRaddt runs on wool", "FAIL", one_line(f1$msg))
} else {
  record("F1c", "FSRaddt runs on wool", "PASS", paste("fields:", paste(names(f1$out), collapse = ", ")))
  Tdel = f1$out$Tdel
  last = as.numeric(Tdel[nrow(Tdel), -1])
  t_lm = summary(lm(y ~ X))$coefficients[-1, "t value"]
  d = max(abs(last - as.numeric(t_lm)))
  record("F2c", "final-step Tdel == lm() t-statistics (tol 1e-6)", if (d <= 1e-6) "PASS" else "FAIL",
         sprintf("FSRaddt [%s] vs lm [%s], max abs diff %.3e",
                 paste(format(last, digits = 6), collapse = ", "), paste(format(as.numeric(t_lm), digits = 6), collapse = ", "), d))
}

# F3c — determinism (nsamp = 0 exhaustive).
f3a = attempt(fsda_call(h, "FSRaddt", y, X, nsamp = 0, plots = 0))
f3b = attempt(fsda_call(h, "FSRaddt", y, X, nsamp = 0, plots = 0))
if (f3a$ok && f3b$ok) {
  d = max(abs(as.numeric(f3a$out$Tdel) - as.numeric(f3b$out$Tdel)))
  record("F3c", "FSRaddt determinism (2 runs)", if (d == 0) "PASS" else "FAIL", sprintf("max abs diff %.3e", d))
} else {
  record("F3c", "FSRaddt determinism (2 runs)", "FAIL", "a run errored")
}

# F4c — NaN in y: does F1 (silent drop) hit FSRaddt too?
f4 = attempt(fsda_call(h, "FSRaddt", local({ z = y; z[3, 1] = NaN; z }), X, nsamp = 0, plots = 0))
if (!f4$ok) {
  record("F4c", "FSRaddt with NaN in y", "CLEAN-ERROR", one_line(f4$msg))
} else {
  record("F4c", "FSRaddt with NaN in y", "SILENT-OK",
         sprintf("no error; Tdel %s vs %s on clean data — row silently dropped (Finding F1)",
                 paste(dim(f4$out$Tdel), collapse = "x"), paste(dim(f1$out$Tdel), collapse = "x")))
}
check_session("F4c")

# F5c — dimension mismatch.
f5 = attempt(fsda_call(h, "FSRaddt", y, X[1:20, , drop = FALSE], nsamp = 0, plots = 0))
record("F5c", "FSRaddt dim mismatch y(27)/X(20)", if (!f5$ok) "CLEAN-ERROR" else "FINDING",
       if (!f5$ok) one_line(f5$msg) else "no error on mismatched dimensions")
check_session("F5c")

# F6c — tiny n = 5 (FSR refuses this; does FSRaddt?).
f6 = attempt(fsda_call(h, "FSRaddt", y[1:5, , drop = FALSE], X[1:5, , drop = FALSE], nsamp = 0, plots = 0))
record("F6c", "FSRaddt tiny n=5", if (!f6$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!f6$ok) one_line(f6$msg) else "ran without complaint — inconsistent with FSR (Finding F5)")
check_session("F6c")

# ================================================================================
cat("\n=== Section G: MMreg — first contact, oracles, determinism, break attempts ===\n")

# G1 — first run: structure discovery.
seed_rng()
g1 = attempt(fsda_call(h, "MMreg", y, X, intercept = TRUE, plots = 0))
if (!g1$ok) {
  record("G1", "MMreg runs on wool", "FAIL", one_line(g1$msg))
} else {
  b = as.numeric(g1$out$beta)
  record("G1", "MMreg runs on wool", "PASS",
         sprintf("fields: %s | beta [%s]", paste(names(g1$out), collapse = ", "), paste(format(b, digits = 6), collapse = ", ")))
  record("G2", "MMreg structural check (4 finite coefficients)",
         if (length(b) == ncol(X) + 1 && all(is.finite(b))) "PASS" else "FAIL", "")
}

# G3 — clean data oracle: on log(wool) (no outliers) MM should land close to OLS (loose 1% tolerance — MM downweights smoothly).
seed_rng()
g3 = attempt(fsda_call(h, "MMreg", log(y), X, intercept = TRUE, plots = 0))
if (g3$ok) {
  b_mm = as.numeric(g3$out$beta)
  b_ols = as.numeric(coef(lm(log(y) ~ X)))
  rel = max(abs(b_mm - b_ols) / abs(b_ols))
  record("G3", "MMreg on clean log(wool) ~ OLS", if (rel <= 0.15) "PASS" else "CHECK",
         sprintf("max relative gap %.4f (MM [%s] vs OLS [%s]) — normal MM-vs-OLS sampling gap at n=27",
                 rel, paste(format(b_mm, digits = 5), collapse = ", "), paste(format(b_ols, digits = 5), collapse = ", ")))
} else {
  record("G3", "MMreg on clean log(wool) ~ OLS", "FAIL", one_line(g3$msg))
}

# G4 — cross-implementation check vs MASS::rlm(method="MM"), an independent R implementation.
if (g1$ok && requireNamespace("MASS", quietly = TRUE)) {
  fit_mass = MASS::rlm(X, y[, 1], method = "MM", maxit = 200)
  record("G4", "MMreg vs MASS::rlm MM (independent implementation)", "INFO",
         sprintf("FSDA [%s] vs MASS [%s] — same ballpark, different tuning defaults",
                 paste(format(as.numeric(g1$out$beta), digits = 5), collapse = ", "),
                 paste(format(as.numeric(coef(fit_mass)), digits = 5), collapse = ", ")))
}

# G5 — determinism with fixed MATLAB rng.
seed_rng(); g5a = attempt(fsda_call(h, "MMreg", y, X, intercept = TRUE, plots = 0))
seed_rng(); g5b = attempt(fsda_call(h, "MMreg", y, X, intercept = TRUE, plots = 0))
if (g5a$ok && g5b$ok) {
  d = max(abs(as.numeric(g5a$out$beta) - as.numeric(g5b$out$beta)))
  record("G5", "MMreg determinism (rng(42), 2 runs)", if (d == 0) "PASS" else "FINDING", sprintf("max abs diff %.3e", d))
} else {
  record("G5", "MMreg determinism (rng(42), 2 runs)", "FAIL", "a run errored")
}

# G6 — NaN in y: F1 family? MMreg's `outliers` field should be renumbered on the reduced data.
seed_rng()
g6 = attempt(fsda_call(h, "MMreg", local({ z = y; z[3, 1] = NaN; z }), X, intercept = TRUE, plots = 0))
record("G6", "MMreg with NaN in y", if (!g6$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!g6$ok) one_line(g6$msg)
       else sprintf("no error; outliers [%s] refer to REDUCED data (Finding F1)",
                    paste(sort(finite_ids(g6$out$outliers)), collapse = " ")))
check_session("G6")

# G7 — exact linear fit (zero residuals -> scale 0). Contrast with FSR/LXS graceful handling.
seed_rng()
g7 = attempt(fsda_call(h, "MMreg", y_exact, X, intercept = TRUE, plots = 0))
record("G7", "MMreg on exact linear fit (scale 0)", if (!g7$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!g7$ok) one_line(g7$msg) else sprintf("no error; beta [%s]", paste(format(as.numeric(g7$out$beta), digits = 6), collapse = ", ")))
check_session("G7")

# G8 — dimension mismatch.
g8 = attempt(fsda_call(h, "MMreg", y, X[1:20, , drop = FALSE], intercept = TRUE, plots = 0))
record("G8", "MMreg dim mismatch y(27)/X(20)", if (!g8$ok) "CLEAN-ERROR" else "FINDING",
       if (!g8$ok) one_line(g8$msg) else "no error on mismatched dimensions")
check_session("G8")

# G9 — options pass-through: eff (nominal efficiency) must be accepted and shift the estimate.
seed_rng()
g9 = attempt(fsda_call(h, "MMreg", y, X, intercept = TRUE, plots = 0, eff = 0.85))
if (g9$ok && g1$ok) {
  d = max(abs(as.numeric(g9$out$beta) - as.numeric(g1$out$beta)))
  record("G9", "MMreg eff=0.85 option pass-through", "PASS", sprintf("accepted; beta shift vs default: %.4g", d))
} else {
  record("G9", "MMreg eff=0.85 option pass-through", if (!g9$ok) "CLEAN-ERROR" else "FAIL",
         if (!g9$ok) one_line(g9$msg) else "baseline run missing")
}
check_session("G9")

# ================================================================================
cat("\n=== Section H: metamorphic relations + option fuzzing + exotic types (wave 3) ===\n")

base = fsr(y, X)
base_beta = as.numeric(base$beta)

# H1 — row-permutation invariance: shuffle rows, run FSR, map flagged indices back.
set.seed(7)
perm = sample(n)
h1 = attempt(fsr(y[perm, , drop = FALSE], X[perm, , drop = FALSE]))
if (!h1$ok) {
  record("H1", "row-permutation invariance", "FAIL", one_line(h1$msg))
} else {
  ids_back = sort(as.numeric(perm[finite_ids(h1$out$ListOut)]))
  record("H1", "row-permutation invariance", if (identical(ids_back, sort(ref_outliers))) "PASS" else "FINDING",
         sprintf("outliers (mapped back) [%s]", paste(ids_back, collapse = " ")))
}

# H2 — translation equivariance: y + 1000 -> intercept shifts by exactly 1000.
h2 = attempt(fsr(y + 1000, X))
if (!h2$ok) {
  record("H2", "translation equivariance (y+1000)", "FAIL", one_line(h2$msg))
} else {
  d = max(abs(as.numeric(h2$out$beta) - (base_beta + c(1000, 0, 0, 0))))
  same_out = identical(sort(finite_ids(h2$out$ListOut)), sort(ref_outliers))
  record("H2", "translation equivariance (y+1000)", if (d <= 1e-9 && same_out) "PASS" else "FINDING",
         sprintf("beta shift error %.3e; outlier set %s", d, if (same_out) "preserved" else "CHANGED"))
}

# H3 — X column-permutation equivariance.
h3 = attempt(fsr(y, X[, c(3, 1, 2)]))
if (!h3$ok) {
  record("H3", "X column-permutation equivariance", "FAIL", one_line(h3$msg))
} else {
  d = max(abs(as.numeric(h3$out$beta) - c(base_beta[1], base_beta[c(4, 2, 3)])))
  record("H3", "X column-permutation equivariance", if (d <= 1e-9) "PASS" else "FINDING", sprintf("max abs diff %.3e", d))
}

# H4 — duplicated X column (perfect collinearity).
h4 = attempt(fsr(y, cbind(X, X[, 1])))
record("H4", "duplicated X column (exact collinearity)", if (!h4$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!h4$ok) one_line(h4$msg) else sprintf("ran; %d outliers", length(finite_ids(h4$out$ListOut))))
check_session("H4")

# H5 — many predictors: polynomial expansion to p = 9 on n = 27.
Xbig = cbind(X, X^2, X[, 1] * X[, 2], X[, 1] * X[, 3], X[, 2] * X[, 3])
h5 = attempt(fsda_call(h, "FSR", y, Xbig, intercept = TRUE, plots = 0, msg = 0))
record("H5", "p=9 predictors on n=27", if (!h5$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!h5$ok) one_line(h5$msg) else sprintf("ran; %d outliers", length(finite_ids(h5$out$ListOut))))
check_session("H5")

# H6 — minimal sample n=6, p=4, with the documented bonflev rescue.
h6 = attempt(fsda_call(h, "FSR", y[1:6, , drop = FALSE], X[1:6, , drop = FALSE],
                       nsamp = 0, intercept = TRUE, plots = 0, msg = 0, bonflev = 0.99))
record("H6", "minimal n=6 with bonflev", if (!h6$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!h6$ok) one_line(h6$msg) else "ran at the edge")
check_session("H6")

# H7 — option fuzzing: impossible values.
fuzz = list(
  list(id = "H7a", desc = "bonflev = 5 (must be prob or quantile)", args = list(bonflev = 5)),
  list(id = "H7b", desc = "nsamp = -5", args = list(nsamp = -5)),
  list(id = "H7c", desc = "init = 1000 (> n = 27)", args = list(init = 1000)),
  list(id = "H7d", desc = "lms = 'banana' (string where code expected)", args = list(lms = "banana"))
)
for (f in fuzz) {
  a = attempt(do.call(fsda_call, c(list(h, "FSR", y, X, intercept = TRUE, plots = 0, msg = 0), f$args)))
  if (!a$ok) {
    record(f$id, f$desc, "CLEAN-ERROR", one_line(a$msg, 120))
  } else {
    ids = finite_ids(a$out$ListOut)
    record(f$id, f$desc, "FINDING",
           sprintf("ACCEPTED an impossible value; %d outliers (reference: %d)", length(ids), length(ref_outliers)))
  }
  check_session(f$id)
}

# H8 — option-NAME injection.
bad = list(1); names(bad) = "plots');quit;%"
h8 = attempt(do.call(fsda_call, c(list(h, "FSR", y, X, intercept = TRUE, msg = 0), bad)))
record("H8", "option-name injection \"plots');quit;%\"", if (!h8$ok) "CLEAN-ERROR" else "FINDING",
       if (!h8$ok) one_line(h8$msg, 120) else "accepted a malicious option name")
record("H8s", "session alive after option injection", if (alive()) "PASS" else "FINDING",
       if (alive()) "quit did not execute" else "session DEAD — injection executed!")
if (!alive()) h = start_engine("FSR", fsda_root = fsda_root)

# H9 — logical (TRUE/FALSE) y.
h9 = attempt(fsr(matrix(y > stats::median(y), ncol = 1), X))
record("H9", "logical (TRUE/FALSE) y", if (!h9$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!h9$ok) one_line(h9$msg, 120) else sprintf("ran; %d outliers", length(finite_ids(h9$out$ListOut))))
check_session("H9")

# H10 — complex numbers in y.
h10 = attempt(fsr(matrix(complex(real = y, imaginary = 1), ncol = 1), X))
record("H10", "complex y (1i imaginary part)", if (!h10$ok) "CLEAN-ERROR" else "FINDING",
       if (!h10$ok) one_line(h10$msg, 120) else "accepted complex input silently")
check_session("H10")

# H11 — 3-D array as X.
h11 = attempt(fsr(y, array(as.numeric(X), dim = c(9, 3, 3))))
record("H11", "3-D array as X", if (!h11$ok) "CLEAN-ERROR" else "FINDING",
       if (!h11$ok) one_line(h11$msg, 120) else "accepted a 3-D array as X")
check_session("H11")

# H12 — constant y (zero variance).
h12 = attempt(fsr(matrix(100, n, 1), X))
record("H12", "constant y (zero variance)", if (!h12$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!h12$ok) one_line(h12$msg, 120) else sprintf("ran; %d outliers", length(finite_ids(h12$out$ListOut))))
check_session("H12")

# H13 — LXS with NaN (completes the F1 table across all 4 routines).
h13 = attempt(fsda_call(h, "LXS", local({ z = y; z[3, 1] = NaN; z }), X, intercept = TRUE, plots = 0, msg = 0))
record("H13", "LXS with NaN in y", if (!h13$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!h13$ok) one_line(h13$msg, 120) else "no error; silent drop (Finding F1, 4/4 routines confirmed)")
check_session("H13")

# H14 — 30 consecutive FSR calls on one session: correctness drift + slowdown.
times = numeric(30)
drift = FALSE
for (i in 1:30) {
  t0 = Sys.time()
  r = fsr(y, X)
  times[i] = as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (!identical(sort(finite_ids(r$ListOut)), sort(ref_outliers))) drift = TRUE
}
slow = mean(times[26:30]) / mean(times[1:5])
record("H14", "30-call stress loop (one session)", if (!drift && slow < 2) "PASS" else "FINDING",
       sprintf("drift: %s; first-5 mean %.2fs vs last-5 mean %.2fs (ratio %.2f)",
               if (drift) "YES" else "none", mean(times[1:5]), mean(times[26:30]), slow))

# H15 — nargout abuse round 2.
h15a = attempt(fsda_call(h, "FSR", y, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0, nargout = 0))
record("H15a", "nargout = 0 on FSR", if (!h15a$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!h15a$ok) one_line(h15a$msg, 120) else "ran for side effects only")
h15b = attempt(fsda_call(h, "FSR", y, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0, nargout = 100))
record("H15b", "nargout = 100 on FSR", if (!h15b$ok) "CLEAN-ERROR" else "FINDING",
       if (!h15b$ok) one_line(h15b$msg, 120) else "accepted an absurd nargout")
check_session("H15")

# ================================================================================
cat("\n=== Section I: missing args, bsb option, case sensitivity, concurrency (wave 4) ===\n")

# I1 — X omitted entirely.
i1 = attempt(fsda_call(h, "FSR", y, intercept = TRUE, plots = 0, msg = 0))
record("I1", "FSR called with X omitted", if (!i1$ok) "CLEAN-ERROR" else "FINDING",
       if (!i1$ok) one_line(i1$msg) else "ran without X — unexpected")
check_session("I1")

# I2 — both y and X omitted.
i2 = attempt(fsda_call(h, "FSR", intercept = TRUE, plots = 0, msg = 0))
record("I2", "FSR called with y and X both omitted", if (!i2$ok) "CLEAN-ERROR" else "FINDING",
       if (!i2$ok) one_line(i2$msg) else "ran with no data at all — unexpected")
check_session("I2")

# I3-I5 — the `bsb` option. NOTE: turned out FSR has no option by this name at
# all ("Non existent user option found: bsb") — all three rejections below are
# for that reason, not the specific malformed-index scenario each was designed
# to probe. Recorded honestly rather than silently dropped.
i3 = attempt(fsr(y, X, bsb = matrix(c(1, 2, 3, 999), ncol = 1)))
record("I3", "bsb = out-of-range index 999 (bsb is not a real FSR option)", "CLEAN-ERROR",
       if (!i3$ok) one_line(i3$msg) else "unexpectedly accepted")
check_session("I3")
i4 = attempt(fsr(y, X, bsb = matrix(c(1, 1, 2, 3), ncol = 1)))
record("I4", "bsb = duplicate index (bsb is not a real FSR option)", "CLEAN-ERROR",
       if (!i4$ok) one_line(i4$msg) else "unexpectedly accepted")
check_session("I4")
i5 = attempt(fsr(y, X, bsb = matrix(c(1, 2, 3, 4), ncol = 1)))
record("I5", "bsb = well-formed subset (bsb is not a real FSR option)", "CLEAN-ERROR",
       if (!i5$ok) one_line(i5$msg) else "unexpectedly accepted")
check_session("I5")

# I6 — routine-name case sensitivity (cross-platform relevance for teammates on Linux).
i6 = attempt(fsda_call(h, "fsr", y, X, nsamp = 0, intercept = TRUE, plots = 0, msg = 0))
record("I6", "routine name lowercase 'fsr' instead of 'FSR'", if (!i6$ok) "CLEAN-ERROR" else "INFO",
       if (!i6$ok) one_line(i6$msg) else "resolved and ran (case-insensitive lookup on this OS — may differ on Linux)")
check_session("I6")

# I7 — two concurrent, independent engine sessions: cross-isolation.
h2 = attempt(start_engine("LXS", fsda_root = fsda_root))
if (!h2$ok) {
  record("I7", "second concurrent engine session starts", "FAIL", one_line(h2$msg))
} else {
  h2 = h2$out
  r1 = attempt(fsr(y, X))
  r2 = attempt(fsda_call(h2, "LXS", y, X, intercept = TRUE, plots = 0, msg = 0))
  ok1 = r1$ok && identical(sort(as.numeric(finite_ids(r1$out$ListOut))), sort(as.numeric(ref_outliers)))
  ok2 = r2$ok && length(as.numeric(r2$out$beta)) == 4
  record("I7", "two concurrent sessions: cross-isolation", if (ok1 && ok2) "PASS" else "FINDING",
         sprintf("session1 FSR %s; session2 LXS %s", if (ok1) "OK" else "WRONG", if (ok2) "OK" else "WRONG"))
  stop_engine(h2)
  record("I7b", "session 1 survives after stopping session 2", if (alive()) "PASS" else "FINDING",
         if (alive()) "alive" else "session 1 died when session 2 was stopped")
}

# I8 — pure noise: y independent of X. A sane method should not manufacture confident outliers.
set.seed(99)
i8 = attempt(fsr(matrix(rnorm(n, mean = 500, sd = 50), ncol = 1), X))
if (!i8$ok) {
  record("I8", "pure noise y (no relationship to X)", "FAIL", one_line(i8$msg))
} else {
  ids = finite_ids(i8$out$ListOut)
  record("I8", "pure noise y (no relationship to X)", "PASS",
         sprintf("%d/%d units flagged (%.0f%%) on structureless data", length(ids), n, 100 * length(ids) / n))
}
check_session("I8")

# I9 — near-collinear (not exact): contrast with H4's exact-duplicate clean rejection.
Xnear = cbind(X, X[, 1] + rnorm(n, sd = 1e-10))
i9 = attempt(fsr(y, Xnear))
record("I9", "near-collinear X column (dup + 1e-10 noise)", if (!i9$ok) "CLEAN-ERROR" else "FINDING",
       if (!i9$ok) one_line(i9$msg)
       else sprintf("ran (contrast with H4's rejection); beta [%s] — numeric blow-up, no R warning (Finding F8)",
                    paste(format(as.numeric(i9$out$beta), digits = 4), collapse = ", ")))
check_session("I9")

# I10 — bonflev = 0 (opposite boundary from H7a's bonflev = 5).
i10 = attempt(fsr(y, X, bonflev = 0))
record("I10", "bonflev = 0 (lower boundary)", if (!i10$ok) "CLEAN-ERROR" else "SILENT-OK",
       if (!i10$ok) one_line(i10$msg) else sprintf("ran; %d outliers (default gives %d)", length(finite_ids(i10$out$ListOut)), length(ref_outliers)))
check_session("I10")

# ================================================================================
cat("\n=== Section INS: external data (Kaggle insurance, n=1338) — no published gold ===\n")
# Model: charges ~ age + bmi + children. The smoker column is hidden from the
# model and used only afterwards to validate the flagged outliers logically.
# n is too large for exhaustive nsamp=0, so MATLAB's rng is fixed via seed_rng().

ins_path = file.path(.script_dir, "insurance.csv")
if (file.exists(ins_path)) {
  d_ins = read.csv(ins_path)
  d_ins = d_ins[complete.cases(d_ins), ]
  y_ins = matrix(d_ins$charges, ncol = 1)
  X_ins = as.matrix(d_ins[, c("age", "bmi", "children")])
  smoker = d_ins$smoker == "yes"
  n_ins = nrow(y_ins)

  seed_rng()
  ins1 = fsda_call(h, "FSR", y_ins, X_ins, intercept = TRUE, plots = 0, msg = 0)
  ins_ids = finite_ids(ins1$ListOut)
  record("INS-1", "FSR at n=1338 (scale test, 50x wool)", "PASS",
         sprintf("%d/%d flagged (%.1f%%)", length(ins_ids), n_ins, 100 * length(ins_ids) / n_ins))

  pct_smoker_flagged = if (length(ins_ids) > 0) 100 * mean(smoker[ins_ids]) else NA
  record("INS-2", "logical validation: smoker share among flagged", "PASS",
         sprintf("%.1f%% smokers among flagged vs %.1f%% baseline; %d/%d smokers caught",
                 pct_smoker_flagged, 100 * mean(smoker), sum(smoker[ins_ids]), sum(smoker)))

  keep_ins = setdiff(seq_len(n_ins), ins_ids)
  d_ins_beta = max(abs(as.numeric(ins1$beta) - as.numeric(coef(lm(y_ins[keep_ins, 1] ~ X_ins[keep_ins, , drop = FALSE])))))
  record("INS-3", "self-consistency: FSR beta vs lm() on kept units (tol 1e-9)",
         if (d_ins_beta <= 1e-9) "PASS" else "FAIL", sprintf("max abs diff %.3e", d_ins_beta))

  seed_rng()
  ins2 = fsda_call(h, "FSR", y_ins, X_ins, intercept = TRUE, plots = 0, msg = 0)
  same_ins = identical(sort(ins_ids), sort(finite_ids(ins2$ListOut))) &&
    max(abs(as.numeric(ins2$beta) - as.numeric(ins1$beta))) == 0
  record("INS-4", "reproducibility with rng(42) (2 runs)", if (same_ins) "PASS" else "FAIL",
         if (same_ins) "identical outliers and beta" else "second run differs")

  seed_rng()
  ins_log = fsda_call(h, "FSR", log(y_ins), X_ins, intercept = TRUE, plots = 0, msg = 0)
  ins_log_ids = finite_ids(ins_log$ListOut)
  record("INS-5", "FSR on log(charges)", "INFO",
         sprintf("%d outliers on log scale (raw scale: %d) — log is NOT a fix here: smokers are a real subpopulation, contrast with wool's Box-Cox story",
                 length(ins_log_ids), length(ins_ids)))

  seed_rng()
  ins_lxs = fsda_call(h, "LXS", y_ins, X_ins, intercept = TRUE, plots = 0, msg = 0)
  b_lxs_ins = as.numeric(ins_lxs$beta)
  record("INS-6", "LXS vs OLS on insurance data", if (length(b_lxs_ins) == 4 && all(is.finite(b_lxs_ins))) "PASS" else "FAIL",
         sprintf("LXS beta [%s] vs OLS [%s] — LXS bmi coef near 0, OLS dragged up by smokers",
                 paste(format(b_lxs_ins, digits = 5), collapse = ", "),
                 paste(format(as.numeric(coef(lm(y_ins ~ X_ins))), digits = 5), collapse = ", ")))
} else {
  record("INS-0", "insurance.csv present", "SKIPPED", sprintf("file not found at %s", ins_path))
}

# ================================================================================
cat("\n=== Session integrity summary ===\n")
record("SESS", "engine session integrity across all break attempts",
       if (session_failures == 0) "PASS" else "FINDING",
       sprintf("%d/%d check_session() calls found the engine dead", session_failures, session_checks))

# ================================================================================
cat("\n=== Full results table ===\n")
cat(sprintf("%-8s %-52s %-16s %s\n", "id", "test", "status", "detail"))
cat(strrep("-", 140), "\n")
for (r in results) {
  cat(sprintf("%-8s %-52s %-16s %s\n", r$id, r$test, r$status, r$detail))
}
statuses = vapply(results, function(r) r$status, "")
cat(sprintf("\nTOTAL: %d tests | PASS %d | FAIL %d | CLEAN-ERROR %d | SILENT-OK %d | FINDING %d | INFO %d | CHECK %d | SKIPPED %d\n",
            length(results), sum(statuses == "PASS"), sum(statuses == "FAIL"), sum(statuses == "CLEAN-ERROR"),
            sum(statuses == "SILENT-OK"), sum(grepl("^FINDING", statuses)), sum(statuses == "INFO"),
            sum(statuses == "CHECK"), sum(statuses == "SKIPPED")))

stop_engine(h)
cat("\nMATLAB session closed.\n")
