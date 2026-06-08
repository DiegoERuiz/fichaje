package org.fichaje.controller;

import javax.validation.Valid;
import javax.servlet.http.HttpServletRequest;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import org.fichaje.dto.entity.Mensaje;
import org.fichaje.dto.entity.UsuarioDTO;
import org.fichaje.dto.AuthResponse;
import org.fichaje.dto.RefreshTokenRequest;
import org.fichaje.dto.LoginUsuario;
import org.fichaje.config.security.jwt.JwtProvider;
import org.fichaje.provider.db.entity.Usuario;
import org.fichaje.service.UsuarioService;
import org.fichaje.service.AuditService;

@RestController
@RequestMapping("/auth")
public class AuthController {

	private final AuthenticationManager authenticationManager;
	private final UsuarioService usuarioService;
	private final JwtProvider jwtProvider;
	private final AuditService auditService;

	public AuthController(AuthenticationManager authenticationManager,
			UsuarioService usuarioService,
			JwtProvider jwtProvider,
			AuditService auditService) {
		this.authenticationManager = authenticationManager;
		this.usuarioService = usuarioService;
		this.jwtProvider = jwtProvider;
		this.auditService = auditService;
	}

	@PostMapping("/nuevo")
	public ResponseEntity<?> nuevo(
			@Valid @RequestBody UsuarioDTO nuevoUsuario,
			BindingResult bindingResult) {

		final ResponseEntity<Mensaje> BAD_REQUEST = validarUsuario(nuevoUsuario, bindingResult);
		if (BAD_REQUEST != null)
			return BAD_REQUEST;

		usuarioService.createNewUser(nuevoUsuario);

		return ResponseEntity
				.status(HttpStatus.CREATED)
				.body(new Mensaje("Usuario creado"));
	}

	@PostMapping("/login")
	public ResponseEntity<?> login(
			@Valid @RequestBody LoginUsuario loginUsuario,
			BindingResult bindingResult,
			HttpServletRequest request) {

		if (bindingResult.hasErrors()) {
			return new ResponseEntity<>(new Mensaje("campos mal puestos"),
					HttpStatus.BAD_REQUEST);
		}

		Usuario usuario = usuarioService.findByNumero(loginUsuario.getNumero())
				.orElse(null);
		
		if (usuario == null) {
			return new ResponseEntity<>(new Mensaje("Usuario no encontrado"),
					HttpStatus.UNAUTHORIZED);
		}

		// Verificar si la cuenta está bloqueada
		if (auditService.isAccountLocked(usuario)) {
			return new ResponseEntity<>(
					new Mensaje("Cuenta bloqueada por demasiados intentos fallidos"),
					HttpStatus.FORBIDDEN);
		}

		try {
			Authentication authentication = authenticationManager.authenticate(
					new UsernamePasswordAuthenticationToken(
							loginUsuario.getNumero(),
							loginUsuario.getPassword()));
			SecurityContextHolder.getContext().setAuthentication(authentication);
			
			// Registrar login exitoso
			String clientIp = getClientIpAddress(request);
			auditService.recordSuccessfulLogin(usuario, clientIp);
			
			// Generar tokens
			String accessToken = jwtProvider.generateToken(authentication);
			String refreshToken = jwtProvider.generateRefreshToken(authentication);
			
			AuthResponse authResponse = AuthResponse.builder()
					.accessToken(accessToken)
					.refreshToken(refreshToken)
					.tokenType("Bearer")
					.expiresIn(36000L)  // 10 horas en segundos
					.build();
			
			return ResponseEntity.status(HttpStatus.OK).body(authResponse);
			
		} catch (BadCredentialsException e) {
			// Registrar intento fallido
			auditService.recordFailedLoginAttempt(usuario, getClientIpAddress(request));
			return new ResponseEntity<>(new Mensaje("Contraseña incorrecta"),
					HttpStatus.UNAUTHORIZED);
		}
	}

	/**
	 * Endpoint para refrescar el access token usando un refresh token
	 */
	@PostMapping("/refresh")
	public ResponseEntity<?> refresh(
			@Valid @RequestBody RefreshTokenRequest refreshTokenRequest) {

		try {
			String newAccessToken = jwtProvider.refreshAccessToken(
					refreshTokenRequest.getRefreshToken());
			
			AuthResponse authResponse = AuthResponse.builder()
					.accessToken(newAccessToken)
					.refreshToken(refreshTokenRequest.getRefreshToken())
					.tokenType("Bearer")
					.expiresIn(36000L)  // 10 horas en segundos
					.build();
			
			return ResponseEntity.ok(authResponse);
			
		} catch (Exception e) {
			return new ResponseEntity<>(
					new Mensaje("Refresh token inválido o expirado"),
					HttpStatus.UNAUTHORIZED);
		}
	}

	/**
	 * Extrae la IP del cliente considerando proxies
	 */
	private String getClientIpAddress(HttpServletRequest request) {
		String xForwardedFor = request.getHeader("X-Forwarded-For");
		if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
			return xForwardedFor.split(",")[0].trim();
		}
		return request.getRemoteAddr();
	}

	private ResponseEntity<Mensaje> validarUsuario(UsuarioDTO nuevoUsuario, BindingResult bindingResult) {
		// Validar que los campos requeridos no están en blanco
		if (nuevoUsuario.getDni().isBlank() ||
				nuevoUsuario.getEmail().isBlank() ||
				nuevoUsuario.getNombreEmpleado().isBlank() ||
				nuevoUsuario.getNumero().isBlank()) {
			return ResponseEntity
					.status(HttpStatus.BAD_REQUEST)
					.body(new Mensaje("Los campos nombre, numero, email o dni no pueden estar en blanco"));
		}

		// Validar formato de email y otros campos
		if (bindingResult.hasErrors()) {
			return ResponseEntity
					.status(HttpStatus.BAD_REQUEST)
					.body(new Mensaje("Campos mal puestos o email inválido."));
		}

		// Validar que no existan duplicados
		if (usuarioService.existsByNumero(nuevoUsuario.getNumero())) {
			return ResponseEntity
					.status(HttpStatus.BAD_REQUEST)
					.body(new Mensaje("Ya existe el número de empleado."));
		}

		if (usuarioService.existsByDni(nuevoUsuario.getDni())) {
			return ResponseEntity
					.status(HttpStatus.BAD_REQUEST)
					.body(new Mensaje("Ya existe el dni del empleado."));
		}

		if (usuarioService.existsByEmail(nuevoUsuario.getEmail())) {
			return ResponseEntity
					.status(HttpStatus.BAD_REQUEST)
					.body(new Mensaje("Email en uso."));
		}
		return null;
	}

}
