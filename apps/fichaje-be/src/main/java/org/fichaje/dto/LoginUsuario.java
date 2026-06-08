package org.fichaje.dto;

import javax.validation.constraints.NotBlank;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.fichaje.config.security.validation.ValidPassword;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class LoginUsuario {
    @NotBlank
    private String numero;
    
    @ValidPassword
    private String password;
}
