;; smart-bin-monitoring.clar
;; IoT bin registration, authorized reporting of fill levels, and collection logging.
;; No traits. No cross-contract calls. Designed for clarity and auditability.

;; -----------------------------
;; Admin management
;; -----------------------------
(define-data-var admin (optional principal) none)

(define-private (require-admin (who principal))
  (match (var-get admin)
    admin-p
      (if (is-eq who admin-p) (ok true) (err u401))
    (err u403)))

(define-public (set-admin (new-admin principal))
  (begin
    (try! (if (is-none (var-get admin))
              (begin (var-set admin (some tx-sender)) (ok true))
              (err u409)))
    ;; The first caller becomes admin; optionally can set to different new-admin in same tx
    (try! (require-admin tx-sender))
    (var-set admin (some new-admin))
    (ok true)))

;; -----------------------------
;; Data definitions
;; -----------------------------
(define-constant MAX-LOC-LEN u128)
(define-constant MAX-NOTE-LEN u256)

;; Unique bins keyed by id
(define-map bins
  { id: uint }
  { location: (string-utf8 128),
    capacity: uint,
    active: bool,
    created-at: uint })

;; Authorized reporters per bin (a simple set)
(define-map bin-reporters
  { id: uint, who: principal }
  { authorized: bool })

;; Sequential reports of fill levels per bin
(define-map fill-reports
  { id: uint, seq: uint }
  { level: uint,
    reported-by: principal,
    at-height: uint })

;; Sequential collection events per bin
(define-map collections
  { id: uint, seq: uint }
  { note: (optional (string-utf8 256)),
    by: principal,
    at-height: uint })

;; Per-bin rolling stats and next sequence counters
(define-map bin-stats
  { id: uint }
  { next-report: uint,
    next-collect: uint,
    reports-count: uint,
    collections-count: uint,
    last-level: (optional uint),
    last-report-height: (optional uint) })

;; -----------------------------
;; Helpers
;; -----------------------------
(define-private (assert (cond bool) (ecode uint))
  (if cond (ok true) (err ecode)))

(define-private (bin-exists (id uint))
  (is-some (map-get? bins { id: id })))

(define-private (ensure-bin (id uint))
  (if (bin-exists id) (ok true) (err u404)))

(define-private (ensure-reporter (id uint) (who principal))
  (match (map-get? bin-reporters { id: id, who: who }) r
    (get authorized r)
    false))


;; -----------------------------
;; Admin entrypoints
;; -----------------------------
(define-public (register-bin (id uint) (location (string-utf8 128)) (capacity uint))
  (begin
    (try! (require-admin tx-sender))
    (try! (assert (not (bin-exists id)) u409))
    (map-set bins { id: id }
                 { location: location,
                   capacity: capacity,
                   active: true,
                   created-at: u0 })
    (map-set bin-stats { id: id }
                     { next-report: u0,
                       next-collect: u0,
                       reports-count: u0,
                       collections-count: u0,
                       last-level: none,
                       last-report-height: none })
    (ok true)))

(define-public (set-bin-active (id uint) (active bool))
  (begin
    (try! (require-admin tx-sender))
    (try! (ensure-bin id))
    (let ((b (unwrap! (map-get? bins { id: id }) (err u404))))
      (map-set bins { id: id }
                   { location: (get location b),
                     capacity: (get capacity b),
                     active: active,
                     created-at: (get created-at b) })
      (ok active))))

(define-public (authorize-reporter (id uint) (who principal) (authorized bool))
  (begin
    (try! (require-admin tx-sender))
    (try! (ensure-bin id))
    (map-set bin-reporters { id: id, who: who } { authorized: authorized })
    (ok authorized)))

(define-public (record-collection (id uint) (note (optional (string-utf8 256))))
  (begin
    (try! (require-admin tx-sender))
    (try! (ensure-bin id))
    (let ((stats (unwrap! (map-get? bin-stats { id: id }) (err u500))))
      (map-set collections { id: id, seq: (get next-collect stats) }
                          { note: note,
                            by: tx-sender,
                            at-height: (get next-collect stats) })
      (map-set bin-stats { id: id }
                       { next-report: (get next-report stats),
                         next-collect: (+ u1 (get next-collect stats)),
                         reports-count: (get reports-count stats),
                         collections-count: (+ u1 (get collections-count stats)),
                         last-level: (get last-level stats),
                         last-report-height: (get last-report-height stats) })
      (ok true))))

;; -----------------------------
;; Reporter entrypoint
;; -----------------------------
(define-public (report-fill (id uint) (level uint))
  (begin
    (try! (ensure-bin id))
    (let ((b (unwrap! (map-get? bins { id: id }) (err u404))))
      (try! (assert (get active b) u410))
      (try! (assert (ensure-reporter id tx-sender) u401))
      (try! (assert (<= level u100) u422))
      (let ((stats (unwrap! (map-get? bin-stats { id: id }) (err u500))))
        (map-set fill-reports { id: id, seq: (get next-report stats) }
                               { level: level,
                                 reported-by: tx-sender,
                                 at-height: (get next-report stats) })
        (map-set bin-stats { id: id }
                         { next-report: (+ u1 (get next-report stats)),
                           next-collect: (get next-collect stats),
                           reports-count: (+ u1 (get reports-count stats)),
                           collections-count: (get collections-count stats),
                           last-level: (some level),
                           last-report-height: (some (get next-report stats)) })
        (ok true)))))

;; -----------------------------
;; Read-only views
;; -----------------------------
(define-read-only (get-bin (id uint))
  (map-get? bins { id: id }))

(define-read-only (is-reporter (id uint) (who principal))
  (ok (ensure-reporter id who)))

(define-read-only (get-stats (id uint))
  (map-get? bin-stats { id: id }))

(define-read-only (get-report (id uint) (seq uint))
  (map-get? fill-reports { id: id, seq: seq }))

(define-read-only (get-collection (id uint) (seq uint))
  (map-get? collections { id: id, seq: seq }))

(define-read-only (get-latest-report (id uint))
  (let ((stats (map-get? bin-stats { id: id })))
    (match stats s
      (if (is-eq u0 (get next-report s))
          none
          (map-get? fill-reports { id: id, seq: (- (get next-report s) u1) }))
      none)))

(define-read-only (get-reports-count (id uint))
  (let ((s (map-get? bin-stats { id: id })))
    (match s st (get reports-count st) u0)))

(define-read-only (get-collections-count (id uint))
  (let ((s (map-get? bin-stats { id: id })))
    (match s st (get collections-count st) u0)))
