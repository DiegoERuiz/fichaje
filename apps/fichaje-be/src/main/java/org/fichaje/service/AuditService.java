package org.fichaje.service;

import org.fichaje.provider.db.entity.Usuario;
import org.fichaje.provider.db.repository.UsuarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/**
 * Servicio de auditoría para registrar eventos de seguridad
 */
@Service
public class AuditService {

    private static final Logger logger = LoggerFactory.getLogger(AuditService.class);
    private static final int MAX_FAILED_LOGIN_ATTEMPTS = 5;

    @Autowired
    private UsuarioRepository usuarioRepository;

    /**
     * Registra un login exitoso
     */
    public void recordSuccessfulLogin(Usuario usuario, String ipAddress) {
        usuario.setLastLoginAt(LocalDateTime.now());
        usuario.setLastLoginIp(ipAddress);
        usuario.setFailedLoginAttempts(0);
        usuario.setAccountLocked(false);
        usuarioRepository.save(usuario);
        
        logger.info("Login exitoso para usuario: {} desde IP: {}", usuario.getNumero(), ipAddress);
    }

    /**
     * Registra un intento de login fallido
     */
    public void recordFailedLoginAttempt(Usuario usuario, String ipAddress) {
        int attempts = usuario.getFailedLoginAttempts() != null ? usuario.getFailedLoginAttempts() + 1 : 1;
        usuario.setFailedLoginAttempts(attempts);
        
        if (attempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
            usuario.setAccountLocked(true);
            logger.warn("Cuenta bloqueada por múltiples intentos fallidos: {} desde IP: {}", 
                    usuario.getNumero(), ipAddress);
        } else {
            logger.warn("Intento de login fallido {} para usuario: {} desde IP: {}", 
                    attempts, usuario.getNumero(), ipAddress);
        }
        
        usuarioRepository.save(usuario);
    }

    /**
     * Desbloquea una cuenta
     */
    public void unlockAccount(Usuario usuario) {
        usuario.setAccountLocked(false);
        usuario.setFailedLoginAttempts(0);
        usuarioRepository.save(usuario);
        
        logger.info("Cuenta desbloqueada: {}", usuario.getNumero());
    }

    /**
     * Verifica si una cuenta está bloqueada
     */
    public boolean isAccountLocked(Usuario usuario) {
        return usuario.getAccountLocked() != null && usuario.getAccountLocked();
    }
}
