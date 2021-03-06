Shindo.tests('Fog::Compute[:aws] | volume requests', ['aws']) do

  @volume_format = {
    'availabilityZone'  => String,
    'createTime'        => Time,
    'iops'              => Fog::Nullable::Integer,
    'requestId'         => String,
    'size'              => Integer,
    'snapshotId'        => Fog::Nullable::String,
    'status'            => String,
    'volumeId'          => String,
    'volumeType'        => String
  }

  @volume_attachment_format = {
    'attachTime'  => Time,
    'device'      => String,
    'instanceId'  => String,
    'requestId'   => String,
    'status'      => String,
    'volumeId'    => String
  }

  @volume_status_format = {
    'volumeStatusSet' => [{
      'availabilityZone'  => String,
      'volumeId'          => String,
      'volumeStatus'      => {
        'status'            => String,
        'details'           => [{
          'name'              => String,
          'status'            => String
        }]
      },
      'actionsSet'        => [{
        'code'              => String,
        'description'       => String,
        'eventId'           => String,
        'eventType'         => String
      }],
      'eventsSet'        => [{
        'description'       => String,
        'eventId'           => String,
        'eventType'         => String,
        'notBefore'         => Time,
        'notAfter'          => Time
      }]
    }],
    'requestId' => String
  }

  @volumes_format = {
    'volumeSet' => [{
      'availabilityZone'  => String,
      'attachmentSet'     => Array,
      'createTime'        => Time,
      'iops'              => Fog::Nullable::Integer,
      'size'              => Integer,
      'snapshotId'        => Fog::Nullable::String,
      'status'            => String,
      'tagSet'            => Hash,
      'volumeId'          => String,
      'volumeType'        => String
    }],
    'requestId' => String
  }

  @server = Fog::Compute[:aws].servers.create
  @server.wait_for { ready? }

  tests('success') do
    @volume_id = nil

    tests('#create_volume').formats(@volume_format) do
      data = Fog::Compute[:aws].create_volume(@server.availability_zone, 1).body
      @volume_id = data['volumeId']
      data
    end

    Fog::Compute[:aws].delete_volume(@volume_id)

    tests('#create_volume from snapshot').formats(@volume_format) do
      volume = Fog::Compute[:aws].volumes.create(:availability_zone => 'us-east-1d', :size => 1)
      snapshot = Fog::Compute[:aws].create_snapshot(volume.identity).body
      data = Fog::Compute[:aws].create_volume(@server.availability_zone, nil, 'SnapshotId' => snapshot['snapshotId']).body
      @volume_id = data['volumeId']
      data
    end

    Fog::Compute[:aws].delete_volume(@volume_id)

    tests('#create_volume with type and iops').formats(@volume_format) do
      data = Fog::Compute[:aws].create_volume(@server.availability_zone, 10, 'VolumeType' => 'io1', 'Iops' => 100).body
      @volume_id = data['volumeId']
      data
    end

    Fog::Compute[:aws].delete_volume(@volume_id)

    tests('#create_volume from snapshot with size').formats(@volume_format) do
      volume = Fog::Compute[:aws].volumes.create(:availability_zone => 'us-east-1d', :size => 1)
      snapshot = Fog::Compute[:aws].create_snapshot(volume.identity).body
      data = Fog::Compute[:aws].create_volume(@server.availability_zone, 1, 'SnapshotId' => snapshot['snapshotId']).body
      @volume_id = data['volumeId']
      data
    end

    Fog::Compute[:aws].volumes.get(@volume_id).wait_for { ready? }

    tests('#describe_volumes').formats(@volumes_format) do
      Fog::Compute[:aws].describe_volumes.body
    end

    tests("#describe_volumes('volume-id' => #{@volume_id})").formats(@volumes_format) do
      Fog::Compute[:aws].describe_volumes('volume-id' => @volume_id).body
    end

    tests("#attach_volume(#{@server.identity}, #{@volume_id}, '/dev/sdh')").formats(@volume_attachment_format) do
      Fog::Compute[:aws].attach_volume(@server.identity, @volume_id, '/dev/sdh').body
    end

    Fog::Compute[:aws].volumes.get(@volume_id).wait_for { state == 'in-use' }

    tests("#describe_volume('attachment.device' => '/dev/sdh')").formats(@volumes_format) do
      Fog::Compute[:aws].describe_volumes('attachment.device' => '/dev/sdh').body
    end

    tests("#describe_volume_status('volume-id' => #{@volume_id})").formats(@volume_status_format) do
      pending if Fog.mocking?
      Fog::Compute[:aws].describe_volume_status('volume-id' => @volume_id).body
    end

    tests("#detach_volume('#{@volume_id}')").formats(@volume_attachment_format) do
      Fog::Compute[:aws].detach_volume(@volume_id).body
    end

    Fog::Compute[:aws].volumes.get(@volume_id).wait_for { ready? }

    tests("#modify_volume_attribute('#{@volume_id}', true)").formats(AWS::Compute::Formats::BASIC) do
      Fog::Compute[:aws].modify_volume_attribute(@volume_id, true).body
    end

    tests("#delete_volume('#{@volume_id}')").formats(AWS::Compute::Formats::BASIC) do
      Fog::Compute[:aws].delete_volume(@volume_id).body
    end
  end

  tests('failure') do
    @volume = Fog::Compute[:aws].volumes.create(:availability_zone => @server.availability_zone, :size => 1)

    tests("#attach_volume('i-00000000', '#{@volume.identity}', '/dev/sdh')").raises(Fog::Compute::AWS::NotFound) do
      Fog::Compute[:aws].attach_volume('i-00000000', @volume.identity, '/dev/sdh')
    end

    tests("#attach_volume('#{@server.identity}', 'vol-00000000', '/dev/sdh')").raises(Fog::Compute::AWS::NotFound) do
      Fog::Compute[:aws].attach_volume(@server.identity, 'vol-00000000', '/dev/sdh')
    end

    tests("#detach_volume('vol-00000000')").raises(Fog::Compute::AWS::NotFound) do
      Fog::Compute[:aws].detach_volume('vol-00000000')
    end

    tests("#modify_volume_attribute('vol-00000000', true)").raises(Fog::Compute::AWS::NotFound) do
      Fog::Compute[:aws].modify_volume_attribute('vol-00000000', true)
    end

    tests("#detach_volume('#{@volume.identity}')").raises(Fog::Compute::AWS::Error) do
      Fog::Compute[:aws].detach_volume(@volume.identity)
    end

    tests("#delete_volume('vol-00000000')").raises(Fog::Compute::AWS::NotFound) do
      Fog::Compute[:aws].delete_volume('vol-00000000')
    end

    # Iops required
    tests("#create_volume('#{@server.availability_zone}', 10, 'VolumeType' => 'io1')").raises(Fog::Compute::AWS::Error) do
      Fog::Compute[:aws].create_volume(@server.availability_zone, 10, 'VolumeType' => 'io1')
    end

    # size too small for iops
    tests("#create_volume('#{@server.availability_zone}', 9, 'VolumeType' => 'io1', 'Iops' => 100)").raises(Fog::Compute::AWS::Error) do
      Fog::Compute[:aws].create_volume(@server.availability_zone, 9, 'VolumeType' => 'io1', 'Iops' => 100)
    end

    # iops:size ratio too big
    tests("#create_volume('#{@server.availability_zone}', 10, 'VolumeType' => 'io1', 'Iops' => 101)").raises(Fog::Compute::AWS::Error) do
      Fog::Compute[:aws].create_volume(@server.availability_zone, 10, 'VolumeType' => 'io1', 'Iops' => 101)
    end

    # iops invalid value (lower than 100)
    tests("#create_volume('#{@server.availability_zone}', 10, 'VolumeType' => 'io1', 'Iops' => 99)").raises(Fog::Compute::AWS::Error) do
      Fog::Compute[:aws].create_volume(@server.availability_zone, 10, 'VolumeType' => 'io1', 'Iops' => 99)
    end

    # iops invalid value (greater than 4000)
    tests("#create_volume('#{@server.availability_zone}', 1024, 'VolumeType' => 'io1', 'Iops' => 4001)").raises(Fog::Compute::AWS::Error) do
      Fog::Compute[:aws].create_volume(@server.availability_zone, 1024, 'VolumeType' => 'io1', 'Iops' => 4001)
    end

    @volume.destroy
  end

  @server.destroy
end
