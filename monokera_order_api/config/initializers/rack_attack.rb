# frozen_string_literal: true

# config/initializers/rack_attack.rb (for Rails apps)

class Rack::Attack
  # Protected paths that require authorized IPs
  PROTECTED_PATHS = {
    # admin: "/admin",
    api: "/api/v1"
  }.freeze

  # Method to normalize IPs (handles IPv4-mapped IPv6 like ::ffff:127.0.0.1)
  def self.normalize_ip(ip)
    ip_str = ip.to_s
    # Convert ::ffff:127.0.0.1 to 127.0.0.1
    ip_str.gsub(/^::ffff:/i, "")
  end

  # Check if the IP is allowed
  def self.ip_allowed?(request_ip, allowed_ips)
    normalized = normalize_ip(request_ip)
    allowed_ips.any? do |allowed|
      normalized == allowed || request_ip.to_s == allowed || allowed == "localhost"
    end
  end

  # Block access to protected paths from unauthorized IPs
  PROTECTED_PATHS.each do |name, path|
    blocklist("block #{name} access") do |req|
      allowed_ips = Settings.ips
      path_matches = path.start_with?("/api") ? req.path.start_with?(path) : req.path.include?(path)
      path_matches && !ip_allowed?(req.ip, allowed_ips)
    end
  end

  # Limit number of requests per IP (only for allowed IPs)
  throttle("requests by ip", limit: 60, period: 60) do |req|
    req.ip
  end
end
