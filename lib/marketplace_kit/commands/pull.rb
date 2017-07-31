module MarketplaceKit
  module Commands
    class Pull < BaseCommand
      def execute
        puts 'Pull command started!'.green
        ensure_tmp_folder_exist

        puts 'Requesting system backup...'.yellow
        response = send_backup_request

        puts 'Waiting for backup to finish'.yellow
        success_response = wait_for_backup(response[:body]['id']) if response.success?

        download_and_unzip_exported_zip(success_response) if success_response
      end

      protected

      def send_backup_request
        gateway.backup
      end

      def wait_for_backup(backup_id)
        backup_response = gateway.get_deploy(backup_id)
        return handle_deploy_result(backup_response) if deploy_finished?(backup_response)

        print '.'
        sleep 5
        wait_for_backup(backup_id)
      end

      def download_and_unzip_exported_zip(release)
        url = release.body['zip_file']['url']
        url = url.prepend(MarketplaceKit.config.url) if url.start_with?('/')

        system "curl -o marketplace_release.zip '#{url}'"
        system 'unzip -o marketplace_release.zip -d marketplace_builder'
      end

      private

      def deploy_finished?(deploy_response)
        %w(success error).include?(deploy_response.body['status'])
      end

      def handle_deploy_result(deploy_response)
        print "\n"
        if deploy_response.body['status'] == 'success'
          puts 'success'.green
          deploy_response
        else
          parsed_error = JSON.parse(deploy_response.body['error'])
          MarketplaceKit.logger.log_api_error parsed_error['message'], parsed_error['details']
        end
      end
    end
  end
end
