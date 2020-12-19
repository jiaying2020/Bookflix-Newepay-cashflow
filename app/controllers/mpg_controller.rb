class MpgController < ApplicationController

    require 'digest'
    skip_before_action :verify_authenticity_token, only: [:return, :notify]

    # 金流第62頁-TradeInfo 內含參數欄位-
    def checkout
    merchantID = 'MS317365402' #填入你的商店號碼
    version = '1.4'
    respondType = 'JSON'
    timeStamp = Time.now.to_i.to_s
    merchantOrderNo = "CallBack"  + Time.now.to_i.to_s
    amt = @product.price
    itemDesc = @product.title
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

  def notify
    Logger.new("#{Rails.root}/notify.log").try("info",params)
  end

  def return
    Logger.new("#{Rails.root}/return.log").try("info",params)
  end



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

end
