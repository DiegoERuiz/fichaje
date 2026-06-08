package org.fichaje.config.ratelimit;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Rate limiting filter using Bucket4j
 * Limits requests per IP address per configured duration
 */
@Component
public class RateLimitingFilter extends OncePerRequestFilter {

    private static final Logger logger = LoggerFactory.getLogger(RateLimitingFilter.class);
    
    private final Map<String, Bucket> cache = new ConcurrentHashMap<>();
    private final RateLimitProperties rateLimitProperties;

    @Autowired
    public RateLimitingFilter(RateLimitProperties rateLimitProperties) {
        this.rateLimitProperties = rateLimitProperties;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) 
            throws ServletException, IOException {
        
        if (!rateLimitProperties.isEnabled()) {
            filterChain.doFilter(request, response);
            return;
        }

        String key = getClientKey(request);
        Bucket bucket = resolveBucket(key);

        if (bucket.tryConsume(1)) {
            // Allow request
            filterChain.doFilter(request, response);
        } else {
            // Rate limit exceeded - wait time based on configured duration
            long secondsToWait = rateLimitProperties.getDurationMinutes() * 60;
            
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setHeader("X-Rate-Limit-Retry-After-Seconds", String.valueOf(secondsToWait));
            response.setContentType("application/json");
            response.getWriter().write("{\"error\": \"Rate limit exceeded. Please try again in " + secondsToWait + " seconds\"}");
            
            logger.warn("Rate limit exceeded for IP: {}", key);
        }
    }

    private Bucket resolveBucket(String key) {
        return cache.computeIfAbsent(key, k -> createNewBucket());
    }

    private Bucket createNewBucket() {
        Bandwidth limit = Bandwidth.classic(
            rateLimitProperties.getRequests(), 
            Refill.intervally(
                rateLimitProperties.getRequests(), 
                Duration.ofMinutes(rateLimitProperties.getDurationMinutes())
            )
        );
        return Bucket.builder()
            .addLimit(limit)
            .build();
    }

    private String getClientKey(HttpServletRequest request) {
        // Try to get client IP from X-Forwarded-For header (for reverse proxies)
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        
        // Fallback to remote address
        return request.getRemoteAddr();
    }
}
