package org.fichaje.config.security.validation;

import javax.validation.Constraint;
import javax.validation.Payload;
import java.lang.annotation.*;

/**
 * Anotación para validar fortaleza de contraseña
 */
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PasswordStrengthValidator.class)
@Documented
public @interface ValidPassword {

    String message() default "Contraseña débil";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
