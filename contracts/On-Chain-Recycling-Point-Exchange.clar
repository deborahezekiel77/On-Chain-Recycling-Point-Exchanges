(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-not-enough-points (err u105))

(define-data-var next-challenge-id uint u1)
(define-constant err-challenge-not-found (err u108))
(define-constant err-challenge-expired (err u109))
(define-constant err-challenge-completed (err u110))
(define-constant err-bonus-already-claimed (err u111))
(define-constant err-challenge-not-active (err u112))

(define-fungible-token recycling-points)

(define-map user-contributions principal uint)
(define-map material-types uint {name: (string-ascii 50), points-per-unit: uint})
(define-map contribution-records uint {contributor: principal, material-type: uint, quantity: uint, timestamp: uint})
(define-map reward-catalog uint {name: (string-ascii 50), cost: uint, available: uint})
(define-map user-redemptions principal (list 20 uint))

(define-data-var next-contribution-id uint u1)
(define-data-var next-material-type-id uint u1)
(define-data-var next-reward-id uint u1)
(define-data-var total-contributions uint u0)
(define-data-var total-redemptions uint u0)

(define-public (add-material-type (name (string-ascii 50)) (points-per-unit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> points-per-unit u0) err-invalid-amount)
    (let ((material-id (var-get next-material-type-id)))
      (map-set material-types material-id {name: name, points-per-unit: points-per-unit})
      (var-set next-material-type-id (+ material-id u1))
      (ok material-id))))

(define-public (add-reward (name (string-ascii 50)) (cost uint) (available uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> cost u0) err-invalid-amount)
    (let ((reward-id (var-get next-reward-id)))
      (map-set reward-catalog reward-id {name: name, cost: cost, available: available})
      (var-set next-reward-id (+ reward-id u1))
      (ok reward-id))))

(define-public (contribute-material (material-type-id uint) (quantity uint))
  (let ((material-info (unwrap! (map-get? material-types material-type-id) err-not-found))
        (contribution-id (var-get next-contribution-id))
        (points-earned (* quantity (get points-per-unit material-info)))
        (current-contributions (default-to u0 (map-get? user-contributions tx-sender))))
    (asserts! (> quantity u0) err-invalid-amount)
    (try! (ft-mint? recycling-points points-earned tx-sender))
    (map-set user-contributions tx-sender (+ current-contributions quantity))
    (map-set contribution-records contribution-id 
      {contributor: tx-sender, material-type: material-type-id, quantity: quantity, timestamp: stacks-block-height})
    (var-set next-contribution-id (+ contribution-id u1))
    (var-set total-contributions (+ (var-get total-contributions) quantity))
    (ok {contribution-id: contribution-id, points-earned: points-earned})))

(define-public (redeem-reward (reward-id uint))
  (let ((reward-info (unwrap! (map-get? reward-catalog reward-id) err-not-found))
        (user-balance (ft-get-balance recycling-points tx-sender))
        (current-redemptions (default-to (list) (map-get? user-redemptions tx-sender))))
    (asserts! (>= user-balance (get cost reward-info)) err-not-enough-points)
    (asserts! (> (get available reward-info) u0) err-not-found)
    (try! (ft-burn? recycling-points (get cost reward-info) tx-sender))
    (map-set reward-catalog reward-id 
      {name: (get name reward-info), cost: (get cost reward-info), available: (- (get available reward-info) u1)})
    (map-set user-redemptions tx-sender (unwrap! (as-max-len? (append current-redemptions reward-id) u20) err-invalid-amount))
    (var-set total-redemptions (+ (var-get total-redemptions) u1))
    (ok reward-id)))

(define-public (transfer-points (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (ft-transfer? recycling-points amount tx-sender recipient)))

(define-read-only (get-user-balance (user principal))
  (ft-get-balance recycling-points user))

(define-read-only (get-user-contributions (user principal))
  (default-to u0 (map-get? user-contributions user)))

(define-read-only (get-material-type (material-id uint))
  (map-get? material-types material-id))

(define-read-only (get-reward-info (reward-id uint))
  (map-get? reward-catalog reward-id))

(define-read-only (get-contribution-record (contribution-id uint))
  (map-get? contribution-records contribution-id))

(define-read-only (get-user-redemptions (user principal))
  (default-to (list) (map-get? user-redemptions user)))

(define-read-only (get-total-contributions)
  (var-get total-contributions))

(define-read-only (get-total-redemptions)
  (var-get total-redemptions))

(define-read-only (get-contract-stats)
  {total-contributions: (var-get total-contributions),
   total-redemptions: (var-get total-redemptions),
   next-contribution-id: (var-get next-contribution-id),
   next-material-type-id: (var-get next-material-type-id),
   next-reward-id: (var-get next-reward-id)})

(define-public (update-reward-availability (reward-id uint) (new-availability uint))
  (let ((reward-info (unwrap! (map-get? reward-catalog reward-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set reward-catalog reward-id 
      {name: (get name reward-info), cost: (get cost reward-info), available: new-availability})
    (ok true)))

(define-public (batch-contribute (contributions (list 10 {material-type: uint, quantity: uint})))
  (fold check-and-contribute contributions (ok u0)))

(define-private (check-and-contribute (contribution {material-type: uint, quantity: uint}) (previous-response (response uint uint)))
  (match previous-response
    prev-val (match (contribute-material (get material-type contribution) (get quantity contribution))
                success (ok (+ prev-val (get points-earned success)))
                error (err error))
    error (err error)))

(define-read-only (get-leaderboard-position (user principal))
  (let ((user-total (get-user-contributions user)))
    (if (> user-total u0)
      (ok user-total)
      err-not-found)))

(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok true)))

(define-read-only (get-token-name)
  "Recycling Points")

(define-read-only (get-token-symbol)
  "RCP")

(define-read-only (get-token-decimals)
  u0)

(define-read-only (get-total-supply)
  (ft-get-supply recycling-points))

(begin
  (try! (add-material-type "Plastic Bottles" u10))
  (try! (add-material-type "Glass Bottles" u15))
  (try! (add-material-type "Aluminum Cans" u20))
  (try! (add-material-type "Paper Waste" u5))
  (try! (add-reward "Eco-Friendly Water Bottle" u100 u50))
  (try! (add-reward "Reusable Shopping Bag" u150 u30))
  (try! (add-reward "Solar Power Bank" u500 u10))
  (try! (add-reward "Bamboo Cutlery Set" u75 u25))
  (print "Contract initialized with default material types and rewards")
  (ok true))

(define-map active-multipliers uint {multiplier: uint, start-block: uint, end-block: uint, material-type: (optional uint)})
(define-data-var next-multiplier-id uint u1)
(define-constant err-multiplier-expired (err u106))
(define-constant err-multiplier-not-active (err u107))

(define-public (create-multiplier (multiplier uint) (duration-blocks uint) (material-type (optional uint)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> multiplier u100) err-invalid-amount)
    (asserts! (> duration-blocks u0) err-invalid-amount)
    (let ((multiplier-id (var-get next-multiplier-id))
          (start-block stacks-block-height)
          (end-block (+ stacks-block-height duration-blocks)))
      (map-set active-multipliers multiplier-id 
        {multiplier: multiplier, start-block: start-block, end-block: end-block, material-type: material-type})
      (var-set next-multiplier-id (+ multiplier-id u1))
      (ok multiplier-id))))

(define-private (get-active-multiplier (material-type-id uint))
  (let ((current-block stacks-block-height))
    (fold find-best-multiplier 
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
      {best-multiplier: u100, material-match: false, current-block: current-block, target-material: material-type-id})))

(define-private (find-best-multiplier (multiplier-id uint) (acc {best-multiplier: uint, material-match: bool, current-block: uint, target-material: uint}))
  (match (map-get? active-multipliers multiplier-id)
    multiplier-data 
      (if (and (>= (get current-block acc) (get start-block multiplier-data))
               (<= (get current-block acc) (get end-block multiplier-data)))
        (match (get material-type multiplier-data)
          some-material
            (if (is-eq some-material (get target-material acc))
              {best-multiplier: (get multiplier multiplier-data), material-match: true, 
               current-block: (get current-block acc), target-material: (get target-material acc)}
              acc)
          (if (not (get material-match acc))
            {best-multiplier: (if (> (get multiplier multiplier-data) (get best-multiplier acc)) (get multiplier multiplier-data) (get best-multiplier acc)), 
             material-match: false, current-block: (get current-block acc), target-material: (get target-material acc)}
            acc))
        acc)
    acc))

(define-public (contribute-material-with-multiplier (material-type-id uint) (quantity uint))
  (let ((material-info (unwrap! (map-get? material-types material-type-id) err-not-found))
        (contribution-id (var-get next-contribution-id))
        (base-points (* quantity (get points-per-unit material-info)))
        (multiplier-result (get-active-multiplier material-type-id))
        (final-points (/ (* base-points (get best-multiplier multiplier-result)) u100))
        (current-contributions (default-to u0 (map-get? user-contributions tx-sender))))
    (asserts! (> quantity u0) err-invalid-amount)
    (try! (ft-mint? recycling-points final-points tx-sender))
    (map-set user-contributions tx-sender (+ current-contributions quantity))
    (map-set contribution-records contribution-id 
      {contributor: tx-sender, material-type: material-type-id, quantity: quantity, timestamp: stacks-block-height})
    (var-set next-contribution-id (+ contribution-id u1))
    (var-set total-contributions (+ (var-get total-contributions) quantity))
    (ok {contribution-id: contribution-id, points-earned: final-points, multiplier-applied: (get best-multiplier multiplier-result)})))

(define-read-only (get-current-multiplier (material-type-id uint))
  (get best-multiplier (get-active-multiplier material-type-id)))

(define-read-only (get-multiplier-info (multiplier-id uint))
  (map-get? active-multipliers multiplier-id))

  (define-map community-challenges uint {
  title: (string-ascii 50),
  target-quantity: uint,
  current-progress: uint,
  bonus-percentage: uint,
  deadline-block: uint,
  is-completed: bool,
  participant-count: uint
})

(define-map challenge-participants {challenge-id: uint, user: principal} {
  contribution-amount: uint,
  has-claimed-bonus: bool
})


(define-public (create-community-challenge 
  (title (string-ascii 50))
  (target-quantity uint)
  (bonus-percentage uint)
  (duration-blocks uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> target-quantity u0) err-invalid-amount)
    (asserts! (> bonus-percentage u0) err-invalid-amount)
    (asserts! (> duration-blocks u0) err-invalid-amount)
    (let ((challenge-id (var-get next-challenge-id))
          (deadline (+ stacks-block-height duration-blocks)))
      (map-set community-challenges challenge-id {
        title: title,
        target-quantity: target-quantity,
        current-progress: u0,
        bonus-percentage: bonus-percentage,
        deadline-block: deadline,
        is-completed: false,
        participant-count: u0
      })
      (var-set next-challenge-id (+ challenge-id u1))
      (ok challenge-id))))

(define-public (participate-in-challenge (challenge-id uint) (contribution-quantity uint))
  (let ((challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
        (participant-key {challenge-id: challenge-id, user: tx-sender})
        (existing-participation (map-get? challenge-participants participant-key)))
    (asserts! (<= stacks-block-height (get deadline-block challenge)) err-challenge-expired)
    (asserts! (not (get is-completed challenge)) err-challenge-completed)
    (asserts! (> contribution-quantity u0) err-invalid-amount)
    
    (let ((new-progress (+ (get current-progress challenge) contribution-quantity))
          (existing-amount (match existing-participation
                             some-participation (get contribution-amount some-participation)
                             u0))
          (is-new-participant (is-none existing-participation)))
      
      (map-set challenge-participants participant-key {
        contribution-amount: (+ existing-amount contribution-quantity),
        has-claimed-bonus: false
      })
      
      (map-set community-challenges challenge-id {
        title: (get title challenge),
        target-quantity: (get target-quantity challenge),
        current-progress: new-progress,
        bonus-percentage: (get bonus-percentage challenge),
        deadline-block: (get deadline-block challenge),
        is-completed: (>= new-progress (get target-quantity challenge)),
        participant-count: (if is-new-participant (+ (get participant-count challenge) u1) (get participant-count challenge))
      })
      (ok new-progress))))


(define-public (claim-challenge-bonus (challenge-id uint))
  (let ((challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
        (participant-key {challenge-id: challenge-id, user: tx-sender})
        (participation (unwrap! (map-get? challenge-participants participant-key) err-not-found)))
    (asserts! (get is-completed challenge) err-challenge-not-active)
    (asserts! (not (get has-claimed-bonus participation)) err-bonus-already-claimed)

    (let ((bonus-points (/ (* (get contribution-amount participation) (get bonus-percentage challenge)) u100)))
      (try! (ft-mint? recycling-points bonus-points tx-sender))
      (map-set challenge-participants participant-key {
        contribution-amount: (get contribution-amount participation),
        has-claimed-bonus: true
      })
      (ok bonus-points))))

(define-read-only (get-challenge-info (challenge-id uint))
  (map-get? community-challenges challenge-id))

(define-read-only (get-user-challenge-participation (challenge-id uint) (user principal))
  (map-get? challenge-participants {challenge-id: challenge-id, user: user}))

(define-map user-streaks principal {
  current-streak: uint,
  longest-streak: uint,
  last-contribution-block: uint,
  total-milestones-claimed: uint
})

(define-map streak-milestones uint {
  required-streak: uint,
  bonus-points: uint,
  title: (string-ascii 40)
})

(define-data-var streak-interval-blocks uint u144)
(define-data-var next-milestone-id uint u1)
(define-constant err-streak-milestone-claimed (err u113))
(define-constant err-streak-requirement-not-met (err u114))

(define-public (initialize-streak-milestones)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set streak-milestones u1 {required-streak: u7, bonus-points: u50, title: "Week Warrior"})
    (map-set streak-milestones u2 {required-streak: u30, bonus-points: u250, title: "Monthly Champion"})
    (map-set streak-milestones u3 {required-streak: u90, bonus-points: u1000, title: "Quarter Legend"})
    (map-set streak-milestones u4 {required-streak: u365, bonus-points: u5000, title: "Year Hero"})
    (var-set next-milestone-id u5)
    (ok true)))

(define-private (update-user-streak (user principal))
  (let ((streak-data (default-to {current-streak: u0, longest-streak: u0, last-contribution-block: u0, total-milestones-claimed: u0}
                        (map-get? user-streaks user)))
        (blocks-since-last (- stacks-block-height (get last-contribution-block streak-data)))
        (interval (var-get streak-interval-blocks)))
    (if (<= blocks-since-last interval)
      (let ((new-streak (+ (get current-streak streak-data) u1)))
        (map-set user-streaks user {
          current-streak: new-streak,
          longest-streak: (if (> new-streak (get longest-streak streak-data)) new-streak (get longest-streak streak-data)),
          last-contribution-block: stacks-block-height,
          total-milestones-claimed: (get total-milestones-claimed streak-data)
        })
        new-streak)
      (begin
        (map-set user-streaks user {
          current-streak: u1,
          longest-streak: (get longest-streak streak-data),
          last-contribution-block: stacks-block-height,
          total-milestones-claimed: (get total-milestones-claimed streak-data)
        })
        u1))))

(define-public (contribute-and-update-streak (material-type-id uint) (quantity uint))
  (begin
    (try! (contribute-material material-type-id quantity))
    (let ((new-streak (update-user-streak tx-sender)))
      (ok {streak: new-streak}))))

(define-public (claim-streak-milestone (milestone-id uint))
  (let ((milestone (unwrap! (map-get? streak-milestones milestone-id) err-not-found))
        (streak-data (unwrap! (map-get? user-streaks tx-sender) err-not-found)))
    (asserts! (>= (get current-streak streak-data) (get required-streak milestone)) err-streak-requirement-not-met)
    (asserts! (< (get total-milestones-claimed streak-data) milestone-id) err-streak-milestone-claimed)
    (try! (ft-mint? recycling-points (get bonus-points milestone) tx-sender))
    (map-set user-streaks tx-sender {
      current-streak: (get current-streak streak-data),
      longest-streak: (get longest-streak streak-data),
      last-contribution-block: (get last-contribution-block streak-data),
      total-milestones-claimed: milestone-id
    })
    (ok (get bonus-points milestone))))

(define-read-only (get-user-streak (user principal))
  (map-get? user-streaks user))

(define-read-only (get-milestone-info (milestone-id uint))
  (map-get? streak-milestones milestone-id))

(define-public (set-streak-interval (new-interval uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set streak-interval-blocks new-interval)
    (ok true)))