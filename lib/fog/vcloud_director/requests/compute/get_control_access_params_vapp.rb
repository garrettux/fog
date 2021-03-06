module Fog
  module Compute
    class VcloudDirector
      class Real
        # Retrieve access control information for a vApp.
        #
        # @param [String] id Object identifier of the vApp.
        # @return [Excon::Response]
        #   * body<~Hash>:
        #
        # @see http://pubs.vmware.com/vcd-51/topic/com.vmware.vcloud.api.reference.doc_51/doc/operations/GET-ControlAccessParams-vApp.html
        # @since vCloud API 0.9
        def get_control_access_params_vapp(id)
          request(
            :expects    => 200,
            :idempotent => true,
            :method     => 'GET',
            :parser     => Fog::ToHashDocument.new,
            :path       => "vApp/#{id}/controlAccess"
          )
        end
      end
    end
  end
end
