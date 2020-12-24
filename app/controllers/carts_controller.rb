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
        hashKey = 'PED4txrEktTyEDSx8hG0zep0DrKTTT0X' #填入你的key
        hashIV = 'CQBc2k1cpdHqEEkP' #填入你的IV
    
    
        data = "MerchantID=#{merchantID}&RespondType=#{respondType}&TimeStamp=#{timeStamp}&Version=#{version}&MerchantOrderNo=#{merchantOrderNo}&Amt=#{amt}&ItemDesc=#{itemDesc}&TradeLimit=120"
    
        data = addpadding(data)
        aes = encrypt_data(data, hashKey, hashIV, 'AES-256-CBC')
        checkValue = "HashKey=#{hashKey}&#{aes}&HashIV=#{hashIV}"
    
        @merchantID = merchantID
        @tradeInfo = aes
        @tradeSha  = Digest::SHA256.hexdigest(checkValue).upcase
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
            
            cart = Cart.not_paid.find_by(merchantOrderNo: merchantOrderNo)
            if cart 
              # 只讓特定非即時付款方式狀態變化，避免二次執行
              if result["PaymentType"] == "CVS"
                cart.payment.paid!
                cart.paid!
             
              elsif result["PaymentType"] == "VACC"
                cart.payment.paid!
                cart.paid!

              elsif result["PaymentType"] == "BARCODE"
                cart.payment.paid!
                cart.paid!

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
      
      def return
        Logger.new("#{Rails.root}/return.log").try("info", params)
    
        hashKey = 'PED4txrEktTyEDSx8hG0zep0DrKTTT0X' #填入你的key
        hashIV = 'CQBc2k1cpdHqEEkP' #填入你的IV
    
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
        redirect_to products_path
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

      def removedPadding(data)
        blocksize = 32
        loop do
          lastHex = data.last.bytes.first
          break if lastHex >= blocksize
          data = data[0...-lastHex]
        end
        return data
      end
    
      def decrypt_data(data, key, iv, cipher_type)
        cipher = OpenSSL::Cipher.new(cipher_type)
        cipher.decrypt
        cipher.key = key
        cipher.iv = iv
        packedData = [data.downcase].pack('H*')
        data = removedPadding(cipher.update(packedData))
        begin
          return data + cipher.final
        rescue
          return data
        end
      end



end

