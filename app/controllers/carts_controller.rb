class CartsController < ApplicationController

  skip_before_action :verify_authenticity_token, only: [:return, :notify]
    def add
        current_cart.add_item(params[:id])
        session[:cart1123] = current_cart.serialize
    
        redirect_to products_path, notice: "已加入購物車"
      end
    
      def destroy
        session[:cart1123] = nil
        redirect_to products_path, notice: "購物車已清空"
      end


      def mpg
        merchantID = 'MS317365402' #填入你的商店號碼
        version = '1.4'
        respondType = 'JSON'
        timeStamp = Time.now.to_i.to_s
        merchantOrderNo = "CallBack"  + Time.now.to_i.to_s
        amt = current_cart.total_price
        itemDesc = 'Callback募資商品'
        hashKey = 'hfza7ujU9vGdoRNnwB3HqIfdP2bG4Tq1' #填入你的key
        hashIV = 'Cv9sEeDb2c8fz4BP' #填入你的IV
    
    
        data = "MerchantID=#{merchantID}&RespondType=#{respondType}&TimeStamp=#{timeStamp}&Version=#{version}&MerchantOrderNo=#{merchantOrderNo}&Amt=#{amt}&ItemDesc=#{itemDesc}&TradeLimit=120"
    
        data = addpadding(data)
        aes = encrypt_data(data, hashKey, hashIV, 'AES-256-CBC')
        checkValue = "HashKey=#{hashKey}&#{aes}&HashIV=#{hashIV}"
    
        @merchantID = merchantID
        @tradeInfo = aes
        @tradeSha = Digest::SHA256.hexdigest(checkValue).upcase
        @version = version
      end
    
      # 新增部分-----
      def notify
        if params["Status"] == "SUCCESS"
          tradeInfo = params["TradeInfo"]
          tradeSha = params["TradeSha"]
    
          checkValue = "HashKey=#{HASH_KEY}&#{tradeInfo}&HashIV=#{HASH_IV}"
          if tradeSha == Digest::SHA256.hexdigest(checkValue).upcase
            rawTradeInfo = decrypt_data(tradeInfo, HASH_KEY, HASH_IV, 'AES-256-CBC')
            
            jsonResult = JSON.parse(rawTradeInfo)
            
            result = jsonResult["Result"]
            
            #寫入Log
            Logger.new("#{Rails.root}/notify.log").try("info", result)
            
            merchantOrderNo = result["MerchantOrderNo"]
            
            #利用訂單編號找出cart ，以建立付款但未付款的情況，pledge為not_paid
            pledge = Pledge.not_paid.find_by(merchantOrderNo: merchantOrderNo)
            if pledge 
              # 只讓特定非即時付款方式狀態變化，避免二次執行
              if result["PaymentType"] == "CVS"
                pledge.payment.paid!
                pledge.paid!
             
              elsif result["PaymentType"] == "VACC"
                pledge.payment.paid!
                pledge.paid!

              elsif result["PaymentType"] == "BARCODE"
                pledge.payment.paid!
                pledge.paid!

              else
                #Do Nothing
              end
            end
          end
        end
    
        respond_to do |format|
          format.json {render json: {result: "success"}}
        end
      end

      def paid
        if params["Status"] == "SUCCESS"
    
          tradeInfo = params["TradeInfo"]
          tradeSha = params["TradeSha"]
    
          checkValue = "HashKey=#{HASH_KEY}&#{tradeInfo}&HashIV=#{HASH_IV}"
          
          if tradeSha == Digest::SHA256.hexdigest(checkValue).upcase
            
            #解碼
            rawTradeInfo = decrypt_data(tradeInfo, HASH_KEY, HASH_IV, 'AES-256-CBC')
            
            #轉成JSON
            jsonResult = JSON.parse(rawTradeInfo)
            
            #取出json裡面的Result value, 我們需要的都在裡面
            result = jsonResult["Result"]
            
            #寫入Log
            Logger.new("#{Rails.root}/paid.log").try("info", result)
            
            #取出我們平台的訂單編號
            merchantOrderNo = result["MerchantOrderNo"]
            
            #利用訂單編號找出 pledge，同步付款的情況pledge 會是處於not_selected_yet
            cart = Cart.not_selected_yet.find_by(merchantOrderNo: merchantOrderNo)
            
            # 如果有 pledge
            if cart 
              
              # 建立一個新的payment, status會是已付款
              payment = Payment.paid.new(cart: cart)
              
              # payment裡面也有 merchant_order_no，如果用不到可以拿掉這個column
              payment.merchant_order_no = merchantOrderNo
              
              # transaction_service_provider 設成 mpg
              payment.transaction_service_provider = "mpg"
              
              if result["PaymentType"] == "CREDIT"
                payment.payment_type = "credit_card"
                # TODO: add info from result
              elsif result["PaymentType"] == "WEBATM"
                payment.payment_type = "web_atm"
                # TODO: add info from result
              end
              
              # 設已付款金額
              current_cart.total_price = result["Amt"]
              
              # 儲存，加!會導致失敗的時候出現error
              current_cart.save!
              
              # pledge 改成已付款，Model裡面有override
              current_cart.paid!
              
              redirect_to :root
              return
            end
          end
        end
    
        flash[:alert] = "付款失敗"
        redirect_to products_path
      end
      
      def return
        Logger.new("#{Rails.root}/return.log").try("info", params)
    
        hashKey = 'hfza7ujU9vGdoRNnwB3HqIfdP2bG4Tq1' #填入你的key
        hashIV = 'Cv9sEeDb2c8fz4BP' #填入你的IV
    
        if params["Status"] == "SUCCESS"
    
          tradeInfo = params["TradeInfo"]
          tradeSha = params["TradeSha"]
    
          checkValue = "HashKey=#{hashKey}&#{tradeInfo}&HashIV=#{hashIV}"
          if tradeSha == Digest::SHA256.hexdigest(checkValue).upcase
            rawTradeInfo = decrypt_data(tradeInfo, hashKey, hashIV, 'AES-256-CBC')
            result = JSON.parse(rawTradeInfo)
            Logger.new("#{Rails.root}/return.log").try("info", result)
          end
        end
    
        redirect_to :root
      end
    
      # 新增部分------

  private
    
      def addpadding(data, blocksize = 32)
        len = data.length
        pad = blocksize - ( len % blocksize)
        data += pad.chr * pad
        return data
      end
    
      def encrypt_data(data, key, iv, cipher_type)
        cipher = OpenSSL::Cipher.new(cipher_type)
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv
        encrypted = cipher.update(data) + cipher.final
        return encrypted.unpack("H*")[0].upcase
      end



end

