# frozen_string_literal: true

module Jobs
  class DeactivateUnauthorizedUsers < Jobs::Scheduled
    every 5.minutes
    
    def execute(_)
      User.human_users
        .where(active: true)
        .each do |user|
          deactivate = false
          associated_account = UserAssociatedAccount.find_by(
            provider_name: 'oauth2_basic',
            user_id: user.id
          )
            
          if associated_account.present? && (credentials = associated_account['credentials'])
            token = nil
            
            if credentials['token'] && credentials['expires_at'].to_i > Time.now.to_i
              token = credentials['token']
            elsif credentials['refresh_token']
              token_response = process_response(
                Excon.post(SiteSetting.oauth2_token_url,
                  body: URI.encode_www_form(
                    grant_type: "refresh_token",
                    refresh_token: credentials['refresh_token']
                  )
                )
              )
                            
              if token_response && token_response['access_token']
                token = token_response['access_token']
                
                associated_account.update!(
                  credentials: {
                    token: token_response['access_token'],
                    expires: true,
                    expires_at: Time.now.to_i + token_response['expires_in'],
                    refresh_token: token_response['refresh_token']
                  }
                )
              end
            end
                        
            if token
              account_response = process_response(
                Excon.get(SiteSetting.oauth2_user_json_url,
                  headers: {
                    'Authorization' => "Bearer #{token}",
                    'Accept' => 'application/json'
                  }
                )
              )
                                                          
              if !account_response ||
                !account_response['account'] ||
                !account_response['account']['email_verified'] ||
                account_response['account']['status'] != 'active'
                
                log("'#{user.username}' does not have a verified, active DigitalOcean user account")
                deactivate = true
              else
                log("'#{user.username}' has a verified, active DigitalOcean user account")
              end
            else
              log("DigitalOcean account of '#{user.username}' is no longer authorized")
              deactivate = true
            end
          else
            log("'#{user.username}' has not been authorized with DigitalOcean")
            deactivate = true
          end
          
          if deactivate
            log("Deactivating #{user.username}")

            User.transaction do
              user.deactivate(Discourse.system_user)
            end
          end
      end
    end
    
    def log(message)
      Rails.logger.warn("Deactivate Debugging: #{message}")
    end
    
    def process_response(response)
      return nil if response.status != 200
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        nil
      end 
    end
  end
end
