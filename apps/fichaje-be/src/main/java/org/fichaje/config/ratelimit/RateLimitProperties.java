package org.fichaje.config.ratelimit;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Configuration properties for rate limiting
 */
@Component
@ConfigurationProperties(prefix = "rate-limit")
@Data
public class RateLimitProperties {
    
    private boolean enabled = true;
    private int requests = 100;
    private int durationMinutes = 1;
}
