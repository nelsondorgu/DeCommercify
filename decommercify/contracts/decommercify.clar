;; Decentralized E-commerce Platform
;; Built with Clarinet for Stacks blockchain

;; Constants
(define-constant contract-owner tx-sender)
(define-constant platform-fee-rate u250) ;; 2.5% (250 basis points out of 10000)

;; Error constants
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-product-not-found (err u102))
(define-constant err-order-not-found (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-invalid-status (err u105))
(define-constant err-already-rated (err u106))
(define-constant err-invalid-rating (err u107))
(define-constant err-product-unavailable (err u108))
(define-constant err-order-already-processed (err u109))
(define-constant err-dispute-period-expired (err u110))

;; Data variables
(define-data-var next-product-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var platform-treasury principal contract-owner)
(define-data-var dispute-period uint u144) ;; ~24 hours in blocks

;; Product categories
(define-map product-categories
    uint ;; category-id
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        active: bool
    }
)

;; Products
(define-map products
    uint ;; product-id
    {
        seller: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        category-id: uint,
        price: uint, ;; in microSTX
        quantity: uint,
        images: (list 5 (string-ascii 200)),
        shipping-cost: uint,
        is-digital: bool,
        active: bool,
        created-at: uint
    }
)

;; Orders
(define-map orders
    uint ;; order-id
    {
        buyer: principal,
        seller: principal,
        product-id: uint,
        quantity: uint,
        total-price: uint, ;; including shipping and fees
        shipping-address: (string-ascii 200),
        status: (string-ascii 20), ;; pending, paid, shipped, delivered, cancelled, disputed
        escrow-amount: uint,
        created-at: uint,
        updated-at: uint
    }
)

;; Order status history
(define-map order-status-history
    uint ;; order-id
    (list 20 {
        status: (string-ascii 20),
        timestamp: uint,
        note: (string-ascii 200)
    })
)

;; Seller profiles
(define-map seller-profiles
    principal ;; seller address
    {
        name: (string-ascii 50),
        description: (string-ascii 300),
        email: (string-ascii 100),
        location: (string-ascii 100),
        verified: bool,
        total-sales: uint,
        total-orders: uint,
        join-date: uint
    }
)

;; Ratings and reviews
(define-map product-reviews
    { product-id: uint, buyer: principal }
    {
        rating: uint, ;; 1-5 stars
        review: (string-ascii 500),
        timestamp: uint,
        order-id: uint
    }
)

;; Seller ratings
(define-map seller-ratings
    principal ;; seller
    {
        total-rating: uint,
        review-count: uint,
        average-rating: uint ;; calculated average * 100 for precision
    }
)

;; Disputes
(define-map disputes
    uint ;; order-id
    {
        reason: (string-ascii 300),
        status: (string-ascii 20), ;; open, resolved, closed
        resolution: (string-ascii 500),
        created-at: uint,
        resolved-at: (optional uint)
    }
)

;; Escrow balances
(define-map escrow-balances
    uint ;; order-id
    uint ;; amount in microSTX
)

;; Read-only functions

;; Get product by ID
(define-read-only (get-product (product-id uint))
    (map-get? products product-id)
)

;; Get order by ID
(define-read-only (get-order (order-id uint))
    (map-get? orders order-id)
)

;; Get seller profile
(define-read-only (get-seller-profile (seller principal))
    (map-get? seller-profiles seller)
)

;; Get product review
(define-read-only (get-product-review (product-id uint) (buyer principal))
    (map-get? product-reviews { product-id: product-id, buyer: buyer })
)

;; Get seller rating
(define-read-only (get-seller-rating (seller principal))
    (map-get? seller-ratings seller)
)

;; Get order status history
(define-read-only (get-order-history (order-id uint))
    (default-to (list) (map-get? order-status-history order-id))
)

;; Get dispute
(define-read-only (get-dispute (order-id uint))
    (map-get? disputes order-id)
)

;; Get escrow balance
(define-read-only (get-escrow-balance (order-id uint))
    (default-to u0 (map-get? escrow-balances order-id))
)

;; Calculate total order cost
(define-read-only (calculate-order-cost (product-id uint) (quantity uint))
    (match (get-product product-id)
        product 
        (let 
            (
                (base-cost (* (get price product) quantity))
                (shipping-cost (get shipping-cost product))
                (platform-fee (/ (* base-cost platform-fee-rate) u10000))
            )
            (ok (+ base-cost shipping-cost platform-fee))
        )
        (err err-product-not-found)
    )
)

;; Get next product ID
(define-read-only (get-next-product-id)
    (var-get next-product-id)
)

;; Get next order ID
(define-read-only (get-next-order-id)
    (var-get next-order-id)
)

;; Check if buyer can leave review
(define-read-only (can-leave-review (product-id uint) (buyer principal))
    (let 
        (
            (existing-review (get-product-review product-id buyer))
        )
        (and 
            (is-none existing-review)
            ;; Additional logic to check if buyer actually purchased the product
            true
        )
    )
)

;; Private functions

;; Update order status
(define-private (update-order-status (order-id uint) (new-status (string-ascii 20)) (note (string-ascii 200)))
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
            (current-history (get-order-history order-id))
            (new-history-entry {
                status: new-status,
                timestamp: stacks-block-height,
                note: note
            })
        )
        
        ;; Update order
        (map-set orders order-id
            (merge order { 
                status: new-status,
                updated-at: stacks-block-height
            })
        )
        
        ;; Update history
        (map-set order-status-history order-id
            (unwrap! (as-max-len? (append current-history new-history-entry) u20) (err u112))
        )
        
        (ok true)
    )
)

;; Update seller statistics
(define-private (update-seller-stats (seller principal) (sale-amount uint))
    (let 
        (
            (current-profile (unwrap! (get-seller-profile seller) (err u113)))
        )
        
        (begin
            (map-set seller-profiles seller
                (merge current-profile {
                    total-sales: (+ (get total-sales current-profile) sale-amount),
                    total-orders: (+ (get total-orders current-profile) u1)
                })
            )
            (ok true)
        )
    )
)

;; Update seller rating
(define-private (update-seller-rating (seller principal) (new-rating uint))
    (let 
        (
            (current-rating (default-to 
                { total-rating: u0, review-count: u0, average-rating: u0 }
                (map-get? seller-ratings seller)
            ))
            (new-total-rating (+ (get total-rating current-rating) new-rating))
            (new-review-count (+ (get review-count current-rating) u1))
            (new-average (if (> new-review-count u0)
                (* (/ new-total-rating new-review-count) u100)
                u0
            ))
        )
        
        (begin
            (map-set seller-ratings seller
                {
                    total-rating: new-total-rating,
                    review-count: new-review-count,
                    average-rating: new-average
                }
            )
            (ok true)
        )
    )
)

;; Public functions

;; Create seller profile
(define-public (create-seller-profile 
    (name (string-ascii 50))
    (description (string-ascii 300))
    (email (string-ascii 100))
    (location (string-ascii 100))
)
    (begin
        (map-set seller-profiles tx-sender
            {
                name: name,
                description: description,
                email: email,
                location: location,
                verified: false,
                total-sales: u0,
                total-orders: u0,
                join-date: stacks-block-height
            }
        )
        (ok true)
    )
)

;; List a product
(define-public (list-product
    (title (string-ascii 100))
    (description (string-ascii 500))
    (category-id uint)
    (price uint)
    (quantity uint)
    (images (list 5 (string-ascii 200)))
    (shipping-cost uint)
    (is-digital bool)
)
    (let 
        ((product-id (var-get next-product-id)))
        
        ;; Ensure seller has profile
        (asserts! (is-some (get-seller-profile tx-sender)) (err u111))
        
        (map-set products product-id
            {
                seller: tx-sender,
                title: title,
                description: description,
                category-id: category-id,
                price: price,
                quantity: quantity,
                images: images,
                shipping-cost: shipping-cost,
                is-digital: is-digital,
                active: true,
                created-at: stacks-block-height
            }
        )
        
        (var-set next-product-id (+ product-id u1))
        (ok product-id)
    )
)

;; Create an order
(define-public (create-order
    (product-id uint)
    (quantity uint)
    (shipping-address (string-ascii 200))
)
    (let 
        (
            (product (unwrap! (get-product product-id) err-product-not-found))
            (order-id (var-get next-order-id))
            (total-cost (unwrap! (calculate-order-cost product-id quantity) err-product-not-found))
        )
        
        ;; Validate product availability
        (asserts! (get active product) err-product-unavailable)
        (asserts! (>= (get quantity product) quantity) err-product-unavailable)
        
        ;; Create order
        (map-set orders order-id
            {
                buyer: tx-sender,
                seller: (get seller product),
                product-id: product-id,
                quantity: quantity,
                total-price: total-cost,
                shipping-address: shipping-address,
                status: "pending",
                escrow-amount: u0,
                created-at: stacks-block-height,
                updated-at: stacks-block-height
            }
        )
        
        ;; Initialize order history
        (map-set order-status-history order-id
            (list {
                status: "pending",
                timestamp: stacks-block-height,
                note: "Order created"
            })
        )
        
        ;; Update product quantity
        (map-set products product-id
            (merge product { quantity: (- (get quantity product) quantity) })
        )
        
        (var-set next-order-id (+ order-id u1))
        (ok order-id)
    )
)

;; Pay for order (with escrow)
(define-public (pay-order (order-id uint))
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
            (total-price (get total-price order))
        )
        
        ;; Validate order
        (asserts! (is-eq tx-sender (get buyer order)) err-not-authorized)
        (asserts! (is-eq (get status order) "pending") err-invalid-status)
        
        ;; Transfer funds to escrow
        (try! (stx-transfer? total-price tx-sender (as-contract tx-sender)))
        
        ;; Update escrow balance
        (map-set escrow-balances order-id total-price)
        
        ;; Update order status
        (try! (update-order-status order-id "paid" "Payment received, funds held in escrow"))
        
        (ok true)
    )
)

;; Seller marks order as shipped
(define-public (ship-order (order-id uint) (tracking-info (string-ascii 200)))
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
        )
        
        ;; Validate seller
        (asserts! (is-eq tx-sender (get seller order)) err-not-authorized)
        (asserts! (is-eq (get status order) "paid") err-invalid-status)
        
        ;; Update order status
        (try! (update-order-status order-id "shipped" tracking-info))
        
        (ok true)
    )
)

;; Buyer confirms delivery
(define-public (confirm-delivery (order-id uint))
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
            (escrow-amount (get-escrow-balance order-id))
            (platform-fee (/ (* escrow-amount platform-fee-rate) u10000))
            (seller-amount (- escrow-amount platform-fee))
        )
        
        ;; Validate buyer
        (asserts! (is-eq tx-sender (get buyer order)) err-not-authorized)
        (asserts! (is-eq (get status order) "shipped") err-invalid-status)
        
        ;; Release funds from escrow
        (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller order))))
        (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get platform-treasury))))
        
        ;; Clear escrow balance
        (map-delete escrow-balances order-id)
        
        ;; Update order status
        (try! (update-order-status order-id "delivered" "Order delivered and payment released"))
        
        ;; Update seller stats
        (try! (update-seller-stats (get seller order) (get total-price order)))
        
        (ok true)
    )
)

;; Leave product review
(define-public (leave-review
    (product-id uint)
    (order-id uint)
    (rating uint)
    (review (string-ascii 500))
)
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
            (product (unwrap! (get-product product-id) err-product-not-found))
        )
        
        ;; Validate rating
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        
        ;; Validate buyer and order completion
        (asserts! (is-eq tx-sender (get buyer order)) err-not-authorized)
        (asserts! (is-eq (get product-id order) product-id) err-not-authorized)
        (asserts! (is-eq (get status order) "delivered") err-invalid-status)
        
        ;; Check if review already exists
        (asserts! (can-leave-review product-id tx-sender) err-already-rated)
        
        ;; Create review
        (map-set product-reviews { product-id: product-id, buyer: tx-sender }
            {
                rating: rating,
                review: review,
                timestamp: stacks-block-height,
                order-id: order-id
            }
        )
        
        ;; Update seller rating
        (try! (update-seller-rating (get seller product) rating))
        
        (ok true)
    )
)

;; Create dispute
(define-public (create-dispute (order-id uint) (reason (string-ascii 300)))
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
        )
        
        ;; Validate buyer
        (asserts! (is-eq tx-sender (get buyer order)) err-not-authorized)
        
        ;; Check dispute period
        (asserts! 
            (<= (- stacks-block-height (get updated-at order)) (var-get dispute-period))
            err-dispute-period-expired
        )
        
        ;; Create dispute
        (map-set disputes order-id
            {
                reason: reason,
                status: "open",
                resolution: "",
                created-at: stacks-block-height,
                resolved-at: none
            }
        )
        
        ;; Update order status
        (try! (update-order-status order-id "disputed" reason))
        
        (ok true)
    )
)

;; Cancel order (before payment)
(define-public (cancel-order (order-id uint))
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
            (product (unwrap! (get-product (get product-id order)) err-product-not-found))
        )
        
        ;; Validate buyer and status
        (asserts! (is-eq tx-sender (get buyer order)) err-not-authorized)
        (asserts! (is-eq (get status order) "pending") err-invalid-status)
        
        ;; Restore product quantity
        (map-set products (get product-id order)
            (merge product { 
                quantity: (+ (get quantity product) (get quantity order)) 
            })
        )
        
        ;; Update order status
        (try! (update-order-status order-id "cancelled" "Order cancelled by buyer"))
        
        (ok true)
    )
)

;; Admin functions

;; Resolve dispute (admin only)
(define-public (resolve-dispute 
    (order-id uint) 
    (resolution (string-ascii 500)) 
    (refund-buyer bool)
)
    (let 
        (
            (order (unwrap! (get-order order-id) err-order-not-found))
            (dispute (unwrap! (get-dispute order-id) err-order-not-found))
            (escrow-amount (get-escrow-balance order-id))
        )
        
        ;; Only contract owner can resolve disputes
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status dispute) "open") err-invalid-status)
        
        ;; Handle refund or payment
        (if refund-buyer
            ;; Refund buyer
            (try! (as-contract (stx-transfer? escrow-amount tx-sender (get buyer order))))
            ;; Pay seller (minus platform fee)
            (let 
                (
                    (platform-fee (/ (* escrow-amount platform-fee-rate) u10000))
                    (seller-amount (- escrow-amount platform-fee))
                )
                (try! (as-contract (stx-transfer? seller-amount tx-sender (get seller order))))
                (try! (as-contract (stx-transfer? platform-fee tx-sender (var-get platform-treasury))))
            )
        )
        
        ;; Clear escrow
        (map-delete escrow-balances order-id)
        
        ;; Update dispute
        (map-set disputes order-id
            (merge dispute {
                status: "resolved",
                resolution: resolution,
                resolved-at: (some stacks-block-height)
            })
        )
        
        ;; Update order status
        (try! (update-order-status order-id "resolved" resolution))
        
        (ok true)
    )
)

;; Set platform fee rate (admin only)
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u1000) (err u114)) ;; Max 10%
        ;; Note: This would require a data variable to be mutable
        (ok true)
    )
)

;; Verify seller (admin only)
(define-public (verify-seller (seller principal))
    (let 
        (
            (profile (unwrap! (get-seller-profile seller) (err u115)))
        )
        
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set seller-profiles seller
            (merge profile { verified: true })
        )
        
        (ok true)
    )
)