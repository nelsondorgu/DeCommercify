# Decentralized E-commerce Platform

A decentralized marketplace smart contract built on the Stacks blockchain using Clarity. This platform enables peer-to-peer commerce with built-in escrow, dispute resolution, and seller verification systems.

## 🌟 Features

### Core Functionality
- **Product Listings**: Sellers can list products with detailed information, images, and pricing
- **Order Management**: Complete order lifecycle from creation to delivery
- **Escrow System**: Secure payment holding until order completion
- **Review System**: Buyers can rate products and sellers
- **Dispute Resolution**: Built-in mechanism for handling order disputes
- **Seller Profiles**: Comprehensive seller information and verification

### Security Features
- **Escrow Protection**: Funds held securely until delivery confirmation
- **Time-based Disputes**: Limited dispute window for order issues
- **Role-based Access**: Different permissions for buyers, sellers, and admins
- **Payment Validation**: Comprehensive checks before fund transfers

## 📋 Contract Overview

### Key Components

#### Data Structures
- **Products**: Product listings with metadata, pricing, and inventory
- **Orders**: Order tracking with status history
- **Seller Profiles**: Seller information and statistics
- **Reviews**: Product and seller rating system
- **Disputes**: Conflict resolution tracking
- **Escrow**: Secure payment holding

#### Constants
- **Platform Fee**: 2.5% (250 basis points)
- **Dispute Period**: ~24 hours (144 blocks)

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd decentralized-ecommerce
```

2. Install dependencies:
```bash
clarinet install
```

3. Run tests:
```bash
clarinet test
```

4. Deploy to testnet:
```bash
clarinet deploy --testnet
```

## 📖 Usage Guide

### For Sellers

#### 1. Create Seller Profile
```clarity
(contract-call? .ecommerce create-seller-profile 
    "Your Store Name"
    "Store description"
    "contact@email.com"
    "City, Country")
```

#### 2. List a Product
```clarity
(contract-call? .ecommerce list-product
    "Product Title"
    "Detailed product description"
    u1  ;; category-id
    u1000000  ;; price in microSTX
    u10  ;; quantity
    (list "image1.jpg" "image2.jpg")  ;; images
    u50000  ;; shipping cost
    false)  ;; is-digital
```

#### 3. Ship Order
```clarity
(contract-call? .ecommerce ship-order 
    u1  ;; order-id
    "Tracking number: ABC123")
```

### For Buyers

#### 1. Create Order
```clarity
(contract-call? .ecommerce create-order
    u1  ;; product-id
    u2  ;; quantity
    "123 Main St, City, Country")  ;; shipping address
```

#### 2. Pay for Order
```clarity
(contract-call? .ecommerce pay-order u1)  ;; order-id
```

#### 3. Confirm Delivery
```clarity
(contract-call? .ecommerce confirm-delivery u1)  ;; order-id
```

#### 4. Leave Review
```clarity
(contract-call? .ecommerce leave-review
    u1  ;; product-id
    u1  ;; order-id
    u5  ;; rating (1-5)
    "Great product, fast shipping!")
```

### Order Status Flow

```
pending → paid → shipped → delivered → [reviewed]
    ↓        ↓       ↓
cancelled  disputed  disputed
```

## 🔍 Read-Only Functions

### Product Information
- `get-product(product-id)`: Get product details
- `calculate-order-cost(product-id, quantity)`: Calculate total order cost

### Order Information
- `get-order(order-id)`: Get order details
- `get-order-history(order-id)`: Get order status history
- `get-escrow-balance(order-id)`: Get escrowed amount

### Seller Information
- `get-seller-profile(seller)`: Get seller profile
- `get-seller-rating(seller)`: Get seller rating statistics

### Reviews & Disputes
- `get-product-review(product-id, buyer)`: Get specific review
- `get-dispute(order-id)`: Get dispute information
- `can-leave-review(product-id, buyer)`: Check if buyer can review

## ⚙️ Admin Functions

### Dispute Resolution
```clarity
(contract-call? .ecommerce resolve-dispute
    u1  ;; order-id
    "Resolution details"
    true)  ;; refund-buyer (true/false)
```

### Seller Verification
```clarity
(contract-call? .ecommerce verify-seller 'SP1234...)
```

## 🛡️ Security Considerations

### Escrow Protection
- Funds are held in contract until delivery confirmation
- Automated release upon successful delivery
- Dispute resolution for problematic orders

### Access Control
- Sellers can only modify their own products
- Buyers can only interact with their own orders
- Admin functions restricted to contract owner

### Validation
- Product availability checks before order creation
- Payment validation before escrow deposit
- Status validation for all state changes

## 📊 Economics

### Fee Structure
- **Platform Fee**: 2.5% of order value
- **Paid by**: Deducted from seller payment
- **Collected**: Sent to platform treasury

### Dispute Timeline
- **Dispute Window**: 24 hours after order status change
- **Resolution**: Admin-mediated with refund or payment release

## 🧪 Testing

### Unit Tests
Run the test suite:
```bash
clarinet test
```

### Integration Tests
Test with Clarinet console:
```bash
clarinet console
```

Example test sequence:
```clarity
;; Create seller profile
(contract-call? .ecommerce create-seller-profile "Test Store" "Description" "test@email.com" "Test City")

;; List product
(contract-call? .ecommerce list-product "Test Product" "Description" u1 u1000000 u5 (list) u50000 false)

;; Create and pay for order
(contract-call? .ecommerce create-order u1 u1 "Test Address")
(contract-call? .ecommerce pay-order u1)
```

## 🚧 Limitations & Future Improvements

### Current Limitations
- No automatic dispute resolution
- Limited product categorization
- Basic search functionality
- Single currency support (STX only)

### Planned Features
- Multi-token support
- Advanced search and filtering
- Automated dispute resolution via oracles
- Bulk operations for sellers
- Mobile-optimized frontend

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Clarity best practices
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure backward compatibility

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **Email**: support@your-platform.com

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Guide](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)

---

**Built with ❤️ on Stacks blockchain**