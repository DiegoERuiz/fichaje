package org.fichaje.dto.entity;

import java.util.List;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.fichaje.config.security.validation.ValidPassword;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UsuarioDTO {

	private long id;

	private String email;
	
	@ValidPassword
	private String password;
	
	private String numero;
	private String nombreEmpleado;
	private String dni;

	private List<String> roles;

	private Integer diasVacaciones;

	private Double horasGeneradas;

	private Boolean enVacaciones;

	private Boolean deBaja;

	private Boolean working;

}
