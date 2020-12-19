module CartsHelper
    def current_cart
        @cart ||= Cart.from_hash(session[:cart1123])
      end

end
