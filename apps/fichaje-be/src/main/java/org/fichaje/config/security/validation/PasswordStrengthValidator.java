package org.fichaje.config.security.validation;

import javax.validation.ConstraintValidator;
import javax.validation.ConstraintValidatorContext;
import java.util.regex.Pattern;

/**
 * Validador de fortaleza de contraseña
 * Requiere:
 * - Mínimo 8 caracteres
 * - Al menos una mayúscula
 * - Al menos una minúscula
 * - Al menos un número
 * - Al menos un carácter especial
 */
public class PasswordStrengthValidator implements ConstraintValidator<ValidPassword, String> {

    private static final String PASSWORD_PATTERN =
            "^(?=.*[A-Z])" +      // Al menos una mayúscula
            "(?=.*[a-z])" +       // Al menos una minúscula
            "(?=.*\\d)" +         // Al menos un número
            "(?=.*[@$!%*?&])" +   // Al menos un carácter especial
            "[A-Za-z\\d@$!%*?&]{8,}$"; // Mínimo 8 caracteres

    private static final Pattern pattern = Pattern.compile(PASSWORD_PATTERN);

    @Override
    public void initialize(ValidPassword constraintAnnotation) {
        // Nada que inicializar
    }

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null || value.isEmpty()) {
            return false;
        }

        if (!pattern.matcher(value).matches()) {
            // Personalizar mensaje de error
            context.disableDefaultConstraintViolation();
            context.buildConstraintViolationWithTemplate(
                    "La contraseña debe contener al menos 8 caracteres con mayúscula, minúscula, número y carácter especial (@$!%*?&)")
                    .addConstraintViolation();
            return false;
        }

        return true;
    }
}
