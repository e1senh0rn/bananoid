############ This bouncer will throw bots away. And let them come in again (after some time).
class Blocker

  def self.whitelisted?(address)
    $config.whitelist.include? address
  end
  
  def self.block(address)
    if whitelisted?(address)
      $logger.info("IP #{address} is WHITE-LISTED. Wrong alarm.")
    else
      $logger.warn("Blocking IP #{address}")
      system $config.commands['block'].sub('<INTRUDER>', address)
    end
  end

  def self.unblock(address)
    if whitelisted?(address)
      $logger.info("IP #{address} is WHITE-LISTED. Wrong alarm.")
    else      
      $logger.warn("Releasing IP #{address}")
      system $config.commands['unblock'].sub('<INTRUDER>', address)
    end
  end
end
