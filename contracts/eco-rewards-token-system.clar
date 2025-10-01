;; eco-rewards-token-system.clar
;; Minimal non-transferable reward points ledger.
;; No traits. No cross-contract calls.

(define-data-var admin (optional principal) none)
(define-data-var total-supply uint u0)

(define-map balances { who: principal } { amount: uint })

(define-map events
  { id: uint }
  { who: principal,
    amount: uint,
    kind: (string-utf8 8),
    memo: (optional (string-utf8 64)),
    at-height: uint })

(define-data-var next-event-id uint u0)

(define-private (require-admin (p principal))
  (match (var-get admin)
    a (if (is-eq p a) (ok true) (err u401))
    (err u403)))

(define-public (set-admin (new-admin principal))
  (begin
    (try! (if (is-none (var-get admin))
              (begin (var-set admin (some tx-sender)) (ok true))
              (err u409)))
    (try! (require-admin tx-sender))
    (var-set admin (some new-admin))
    (ok true)))

;; -----------------------------
;; Core
;; -----------------------------
(define-private (assert (cond bool) (ecode uint)) (if cond (ok true) (err ecode)))

(define-private (get-balance (p principal))
  (get amount (default-to { amount: u0 } (map-get? balances { who: p }))))

(define-read-only (balance-of (p principal)) (get-balance p))

(define-read-only (get-total-supply) (var-get total-supply))

(define-private (emit (p principal) (amt uint) (k (string-utf8 8)) (m (optional (string-utf8 64))))
  (let ((eid (var-get next-event-id)))
    (map-set events { id: eid }
                    { who: p,
                      amount: amt,
                      kind: k,
                      memo: m,
                      at-height: (var-get next-event-id) })
    (var-set next-event-id (+ eid u1))
    eid))

(define-public (mint (to principal) (amount uint) (memo (optional (string-utf8 64))))
  (begin
    (try! (require-admin tx-sender))
    (try! (assert (> amount u0) u422))
    (let ((prev (get-balance to)))
      (map-set balances { who: to } { amount: (+ prev amount) })
      (var-set total-supply (+ (var-get total-supply) amount))
      (emit to amount u"mint" memo)
      (ok true))))

(define-public (burn (from principal) (amount uint) (memo (optional (string-utf8 64))))
  (begin
    (try! (require-admin tx-sender))
    (try! (assert (> amount u0) u422))
    (let ((prev (get-balance from)))
      (try! (assert (>= prev amount) u409))
      (map-set balances { who: from } { amount: (- prev amount) })
      (var-set total-supply (- (var-get total-supply) amount))
      (emit from amount u"burn" memo)
      (ok true))))

;; No transfer entrypoint by design (non-transferable points)

;; -----------------------------
;; Views
;; -----------------------------
(define-read-only (get-event (id uint))
  (map-get? events { id: id }))

(define-read-only (get-last-event-id) (var-get next-event-id))
