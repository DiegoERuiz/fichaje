package org.fichaje.config;

import org.fichaje.config.ratelimit.RateLimitingFilter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Configuration for rate limiting filter registration
 */
@Configuration
public class RateLimitConfig {

    @Autowired
    private RateLimitingFilter rateLimitingFilter;

    @Bean
    public FilterRegistrationBean<RateLimitingFilter> rateLimitFilterRegistration() {
        FilterRegistrationBean<RateLimitingFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(rateLimitingFilter);
        registration.addUrlPatterns("/*");
        registration.setName("rateLimitingFilter");
        registration.setOrder(1); // Execute before other filters
        return registration;
    }
}
