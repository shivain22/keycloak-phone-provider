package cc.coopersoft.keycloak.phone.authentication.authenticators.browser;

import cc.coopersoft.keycloak.phone.authentication.forms.SupportPhonePages;
import cc.coopersoft.keycloak.phone.providers.constants.TokenCodeType;
import cc.coopersoft.keycloak.phone.providers.exception.PhoneNumberInvalidException;
import cc.coopersoft.keycloak.phone.providers.spi.PhoneVerificationCodeProvider;
import cc.coopersoft.common.OptionalUtils;
import cc.coopersoft.keycloak.phone.Utils;
import org.jboss.logging.Logger;
import org.keycloak.Config;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.events.Details;
import org.keycloak.events.Errors;
import org.keycloak.events.EventType;
import org.keycloak.forms.login.LoginFormsProvider;
import org.keycloak.models.*;
import org.keycloak.protocol.oidc.OIDCLoginProtocol;
import org.keycloak.provider.ProviderConfigProperty;
import org.keycloak.provider.ProviderConfigurationBuilder;
import org.keycloak.services.validation.Validation;

import jakarta.ws.rs.core.MultivaluedMap;
import jakarta.ws.rs.core.Response;

import java.util.List;

import static cc.coopersoft.keycloak.phone.authentication.forms.SupportPhonePages.*;
import static org.keycloak.provider.ProviderConfigProperty.BOOLEAN_TYPE;

public class PhoneUsernamePasswordFormWithAutoRegistration extends PhoneUsernamePasswordForm implements Authenticator, AuthenticatorFactory {

    private static final Logger logger = Logger.getLogger(PhoneUsernamePasswordFormWithAutoRegistration.class);

    public static final String PROVIDER_ID = "auth-phone-auto-reg-form";

    private static final String CONFIG_ENABLE_AUTO_REGISTRATION = "enableAutoRegistration";
    private static final String CONFIG_AUTO_REG_PHONE_AS_USERNAME = "autoRegPhoneAsUsername";
    private static final String CONFIG_IS_LOGIN_WITH_PHONE_VERIFY = "loginWithPhoneVerify";
    private static final String CONFIG_IS_LOGIN_WITH_PHONE_NUMBER = "loginWithPhoneNumber";
    public static final String VERIFIED_PHONE_NUMBER = "LOGIN_BY_PHONE_VERIFY";

    private boolean isAutoRegistrationEnabled(AuthenticationFlowContext context) {
        return context.getAuthenticatorConfig() != null &&
                "true".equals(context.getAuthenticatorConfig().getConfig()
                        .getOrDefault(CONFIG_ENABLE_AUTO_REGISTRATION, "false"));
    }

    private boolean isAutoRegPhoneAsUsername(AuthenticationFlowContext context) {
        return context.getAuthenticatorConfig() == null ||
                "true".equals(context.getAuthenticatorConfig().getConfig()
                        .getOrDefault(CONFIG_AUTO_REG_PHONE_AS_USERNAME, "true"));
    }

    private boolean isLoginWithPhoneNumber(AuthenticationFlowContext context){
        return context.getAuthenticatorConfig() == null ||
                context.getAuthenticatorConfig().getConfig().getOrDefault(CONFIG_IS_LOGIN_WITH_PHONE_NUMBER, "true").equals("true");
    }

    private boolean isSupportPhone(AuthenticationFlowContext context){
        return context.getAuthenticatorConfig() == null ||
                context.getAuthenticatorConfig().getConfig().getOrDefault(CONFIG_IS_LOGIN_WITH_PHONE_VERIFY, "true").equals("true");
    }

    @Override
    protected boolean validateForm(AuthenticationFlowContext context, MultivaluedMap<String, String> inputData) {
        boolean byPhone = OptionalUtils
                .ofBlank(inputData.getFirst(FIELD_PATH_PHONE_ACTIVATED))
                .map(s -> "true".equalsIgnoreCase(s) || "yes".equalsIgnoreCase(s))
                .orElse(false);

        if (!byPhone) {
            return validateUserAndPassword(context, inputData);
        }

        String phoneNumber = inputData.getFirst(FIELD_PHONE_NUMBER);

        if (Validation.isBlank(phoneNumber)) {
            context.getEvent().error(Errors.USERNAME_MISSING);
            context.form().setAttribute(ATTEMPTED_PHONE_ACTIVATED, true);
            assemblyForm(context, context.form());
            Response challengeResponse = challenge(context, SupportPhonePages.Errors.MISSING.message(), FIELD_PHONE_NUMBER);
            context.forceChallenge(challengeResponse);
            return false;
        }

        String code = inputData.getFirst(FIELD_VERIFICATION_CODE);
        if (Validation.isBlank(code)) {
            invalidVerificationCode(context, phoneNumber);
            return false;
        }

        return validatePhoneWithAutoRegistration(context, phoneNumber, code.trim());
    }

    private boolean validatePhoneWithAutoRegistration(AuthenticationFlowContext context, String phoneNumber, String code) {
        context.clearUser();
        try {
            var validPhoneNumber = Utils.canonicalizePhoneNumber(context.getSession(), phoneNumber);

            return Utils.findUserByPhone(context.getSession(), context.getRealm(), validPhoneNumber)
                    .map(user -> validateVerificationCodeForUser(context, user, validPhoneNumber, code) && validateUserForPhone(context, user, validPhoneNumber))
                    .orElseGet(() -> {
                        if (isAutoRegistrationEnabled(context)) {
                            return handleAutoRegistration(context, validPhoneNumber, code);
                        } else {
                            context.getEvent().error(Errors.USER_NOT_FOUND);
                            context.form().setAttribute(ATTEMPTED_PHONE_ACTIVATED, true)
                                    .setAttribute(ATTEMPTED_PHONE_NUMBER, phoneNumber);
                            assemblyForm(context, context.form());
                            Response challengeResponse = challenge(context, SupportPhonePages.Errors.USER_NOT_FOUND.message(), FIELD_PHONE_NUMBER);
                            context.failureChallenge(AuthenticationFlowError.INVALID_USER, challengeResponse);
                            return false;
                        }
                    });
        } catch (PhoneNumberInvalidException e) {
            context.getEvent().error(Errors.USERNAME_MISSING);
            context.form().setAttribute(ATTEMPTED_PHONE_ACTIVATED, true)
                    .setAttribute(ATTEMPTED_PHONE_NUMBER, phoneNumber);
            assemblyForm(context, context.form());
            Response challengeResponse = challenge(context, e.getErrorType().message(), FIELD_PHONE_NUMBER);
            context.failureChallenge(AuthenticationFlowError.INVALID_USER, challengeResponse);
            return false;
        }
    }

    private boolean validateVerificationCodeForUser(AuthenticationFlowContext context, UserModel user, String phoneNumber, String code) {
        try {
            context.getSession().getProvider(PhoneVerificationCodeProvider.class)
                    .validateCode(user, phoneNumber, code, TokenCodeType.AUTH);
            logger.debug("verification code success!");
            return true;
        } catch (Exception e) {
            context.getEvent().user(user);
            invalidVerificationCode(context, phoneNumber);
            return false;
        }
    }

    private boolean validateUserForPhone(AuthenticationFlowContext context, UserModel user, String phoneNumber) {
        if (!user.isEnabled()) {
            context.getEvent().user(user);
            context.getEvent().error(Errors.USER_DISABLED);
            context.form().setAttribute(ATTEMPTED_PHONE_ACTIVATED, true)
                    .setAttribute(ATTEMPTED_PHONE_NUMBER, phoneNumber);
            assemblyForm(context, context.form());
            Response challengeResponse = challenge(context, "Account disabled");
            context.forceChallenge(challengeResponse);
            return false;
        }
        context.getAuthenticationSession().setAuthNote(VERIFIED_PHONE_NUMBER, phoneNumber);
        context.setUser(user);
        return true;
    }

    private boolean handleAutoRegistration(AuthenticationFlowContext context, String phoneNumber, String code) {
        // First validate the OTP code
        if (!validateVerificationCodeForAutoReg(context, phoneNumber, code)) {
            return false;
        }

        // Check if username conflicts exist
        String username = isAutoRegPhoneAsUsername(context) ? phoneNumber : generateUsername(phoneNumber);
        if (context.getSession().users().getUserByUsername(context.getRealm(), username) != null) {
            context.getEvent().error(Errors.USERNAME_IN_USE);
            context.form().setAttribute(ATTEMPTED_PHONE_ACTIVATED, true)
                    .setAttribute(ATTEMPTED_PHONE_NUMBER, phoneNumber);
            assemblyForm(context, context.form());
            Response challengeResponse = challenge(context, "Username already exists", FIELD_PHONE_NUMBER);
            context.failureChallenge(AuthenticationFlowError.USER_CONFLICT, challengeResponse);
            return false;
        }

        // Create new user
        UserModel newUser = createUserWithPhone(context, phoneNumber);
        if (newUser == null) {
            return false;
        }

        // Mark OTP as validated
        try {
            context.getSession().getProvider(PhoneVerificationCodeProvider.class)
                    .validateCode(newUser, phoneNumber, code, TokenCodeType.AUTH);
        } catch (Exception e) {
            logger.warn("Failed to validate OTP during auto-registration", e);
            invalidVerificationCode(context, phoneNumber);
            return false;
        }

        return validateUserForPhone(context, newUser, phoneNumber);
    }

    private boolean validateVerificationCodeForAutoReg(AuthenticationFlowContext context, String phoneNumber, String code) {
        try {
            PhoneVerificationCodeProvider provider = context.getSession().getProvider(PhoneVerificationCodeProvider.class);
            // Check if there's a valid ongoing process for this phone number
            var tokenCode = provider.ongoingProcess(phoneNumber, TokenCodeType.AUTH);
            if (tokenCode == null || !tokenCode.getCode().equals(code)) {
                invalidVerificationCode(context, phoneNumber);
                return false;
            }
            return true;
        } catch (Exception e) {
            logger.warn("Failed to validate verification code for auto-registration", e);
            invalidVerificationCode(context, phoneNumber);
            return false;
        }
    }

    private UserModel createUserWithPhone(AuthenticationFlowContext context, String phoneNumber) {
        try {
            String username = isAutoRegPhoneAsUsername(context) ? phoneNumber : generateUsername(phoneNumber);
            
            UserModel user = context.getSession().users().addUser(context.getRealm(), username);
            user.setEnabled(true);
            user.setSingleAttribute("phoneNumber", phoneNumber);
            user.setSingleAttribute("phoneNumberVerified", "true");

            context.getEvent().detail(Details.USERNAME, username)
                    .detail(FIELD_PHONE_NUMBER, phoneNumber)
                    .detail("autoRegistration", "true");

            context.getAuthenticationSession().setClientNote(OIDCLoginProtocol.LOGIN_HINT_PARAM, username);

            logger.infov("Auto-registered user: {0} with phone: {1}", username, phoneNumber);
            
            // Fire registration event
            context.newEvent().event(EventType.REGISTER)
                    .user(user)
                    .detail(Details.USERNAME, username)
                    .detail(FIELD_PHONE_NUMBER, phoneNumber)
                    .detail("method", "phone-auto-registration")
                    .success();

            return user;
        } catch (Exception e) {
            logger.error("Failed to create user during auto-registration", e);
            context.getEvent().error(Errors.GENERIC_AUTHENTICATION_ERROR);
            context.form().setAttribute(ATTEMPTED_PHONE_ACTIVATED, true)
                    .setAttribute(ATTEMPTED_PHONE_NUMBER, phoneNumber);
            assemblyForm(context, context.form());
            Response challengeResponse = challenge(context, "Registration failed", FIELD_PHONE_NUMBER);
            context.failureChallenge(AuthenticationFlowError.GENERIC_AUTHENTICATION_ERROR, challengeResponse);
            return null;
        }
    }

    private String generateUsername(String phoneNumber) {
        // Generate a username based on phone number if not using phone as username
        return "user_" + phoneNumber.replaceAll("[^0-9]", "");
    }

    private void invalidVerificationCode(AuthenticationFlowContext context, String number) {
        context.getEvent().error(Errors.INVALID_USER_CREDENTIALS);
        context.form().setAttribute(ATTEMPTED_PHONE_ACTIVATED, true)
                .setAttribute(ATTEMPTED_PHONE_NUMBER, number);
        assemblyForm(context, context.form());
        Response challengeResponse = challenge(context, SupportPhonePages.Errors.NOT_MATCH.message(), FIELD_VERIFICATION_CODE);
        context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS, challengeResponse);
    }

    private LoginFormsProvider assemblyForm(AuthenticationFlowContext context, LoginFormsProvider form) {
        if (isSupportPhone(context))
            form.setAttribute(ATTRIBUTE_SUPPORT_PHONE, true);
        if (isLoginWithPhoneNumber(context)) {
            form.setAttribute("loginWithPhoneNumber", true);
        }
        if (isAutoRegistrationEnabled(context)) {
            form.setAttribute("autoRegistrationEnabled", true);
        }
        return form;
    }

    @Override
    public String getDisplayType() {
        return "Phone Username Password Form with Auto Registration";
    }

    @Override
    public String getHelpText() {
        return "Validates a username and password or phone and verification code from login form. Automatically registers users if they don't exist and auto-registration is enabled.";
    }

    protected static final List<ProviderConfigProperty> CONFIG_PROPERTIES;

    static {
        CONFIG_PROPERTIES = ProviderConfigurationBuilder.create()
                .property().name(CONFIG_IS_LOGIN_WITH_PHONE_VERIFY)
                .type(BOOLEAN_TYPE)
                .label("Login with phone verify")
                .helpText("Input phone number and verification code. `Duplicate phone` must be false.")
                .defaultValue(true)
                .add()
                .property().name(CONFIG_IS_LOGIN_WITH_PHONE_NUMBER)
                .type(BOOLEAN_TYPE)
                .label("Login with phone number")
                .helpText("Input phone number and password. `Duplicate phone` must be false.")
                .defaultValue(true)
                .add()
                .property().name(CONFIG_ENABLE_AUTO_REGISTRATION)
                .type(BOOLEAN_TYPE)
                .label("Enable Auto Registration")
                .helpText("Automatically register users who don't exist when they successfully verify their phone number.")
                .defaultValue(false)
                .add()
                .property().name(CONFIG_AUTO_REG_PHONE_AS_USERNAME)
                .type(BOOLEAN_TYPE)
                .label("Auto Registration: Phone as Username")
                .helpText("Use phone number as username for auto-registered users.")
                .defaultValue(true)
                .add()
                .build();
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        return CONFIG_PROPERTIES;
    }

    @Override
    public Authenticator create(KeycloakSession session) {
        return this;
    }

    @Override
    public void init(Config.Scope config) {
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }
}