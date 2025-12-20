package cc.coopersoft.keycloak.phone.providers.sender;

import cc.coopersoft.keycloak.phone.providers.exception.MessageSendException;
import cc.coopersoft.keycloak.phone.providers.spi.FullSmsSenderAbstractService;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.http.HttpEntity;
import org.apache.http.entity.ContentType;
import org.apache.http.entity.StringEntity;
import org.eclipse.microprofile.config.ConfigProvider;
import org.jboss.logging.Logger;
import org.keycloak.Config;
import org.keycloak.broker.provider.util.SimpleHttp;
import org.keycloak.models.KeycloakSession;

import java.io.IOException;
import java.util.Random;

public class Msg91SmsSenderService extends FullSmsSenderAbstractService {

    public static final String CONFIG_API_SERVER = "url";
    public static final String CONFIG_ENCODING = "encoding";
    public static final String CONFIG_AUTH_KEY = "authKey";
    public static final String CONFIG_TEMPLATE_ID = "templateId";
    private static final Logger logger = Logger.getLogger(Msg91SmsSenderService.class);
    private final String url;
    private final String authKey;
    private final String templateId;
    public Msg91SmsSenderService(Config.Scope config, KeycloakSession session) {
        super(session);

        if (config == null) {
            logger.warn("Config is null for Msg91SmsSenderService");
            this.url = "https://control.msg91.com/api/v5/flow";
            this.authKey = null;
            this.templateId = null;
            return;
        }

        String configUrl = config.get(CONFIG_API_SERVER);
        //this.url = configUrl != null ? configUrl : "https://control.msg91.com/api/v5/flow";
        //this.authKey = config.get(CONFIG_AUTH_KEY);
        //this.templateId = config.get(CONFIG_TEMPLATE_ID);
        this.templateId =
                ConfigProvider.getConfig()
                        .getOptionalValue("kc.spi.message-sender-service.msg91.templateId", String.class)
                        .orElse(config.get("templateId", "6942ac5ffe1f3074f631a9d2"));

        this.url =
                ConfigProvider.getConfig()
                        .getOptionalValue("kc.spi.message-sender-service.msg91.url", String.class)
                        .orElse(config.get("url", "https://control.msg91.com/api/v5/flow"));

        this.authKey =
                ConfigProvider.getConfig()
                        .getOptionalValue("kc.spi.message-sender-service.msg91.authKey", String.class)
                        .orElse(config.get("authKey", "350182AYu7XNrbO6L5fe4817dP1"));


        logger.infov("Msg91 config - URL: {0}, AuthKey: {1}, TemplateId: {2}", 
                    this.url, this.authKey != null ? "[SET]" : "[NULL]", this.templateId);
        
        if (this.authKey == null || this.templateId == null) {
            logger.warn("MSG91 configuration incomplete - authKey or templateId is missing");
        }
    }

    @Override
    public void sendMessage(String phoneNumber, String message) throws MessageSendException {
        String rawJson =
                "{\"template_id\":\"" + templateId + "\","
                        + "\"short_url\":\"0\","
                        + "\"realTimeResponse\":\"1\","
                        + "\"recipients\":[{"
                        +   "\"mobiles\":\"" + phoneNumber + "\","
                        +   "\"number\":\"" + message + "\""
                        + "}]}";

        HttpEntity entity = new StringEntity(
                rawJson,
                ContentType.APPLICATION_JSON
        );

        System.out.println("Msg91 RAW JSON = " + rawJson);


        try {
            SimpleHttp.Response res =
                    SimpleHttp.doPost("https://control.msg91.com/api/v5/flow", session)
                            .header("authkey", authKey)                 // 🔥 EXACT
                            .header("accept", "application/json")
                            .header("content-type", "application/json")
                            .entity(entity)
                            .asResponse();
            if (res.getStatus() >= 200 && res.getStatus() <= 299) {

                logger.debugv("Sent SMS to {0} with contents: {1}. Server responded with: {2}", phoneNumber, message,
                        res.asString());
            } else {
                logger.errorv("Failed to deliver SMS to {0} with contents: {1}. Server responded with: {2}",
                        phoneNumber,
                        message, res.asString());
                throw new MessageSendException("Bulksms API responded with an error.", new Exception(res.asString()));
            }
        } catch (IOException ex) {
            logger.errorv(ex,
                    "Failed to send SMS to {0} with contents: {1}. An IOException occurred while communicating with SMS service {0}.",
                    phoneNumber, message, url);
            throw new MessageSendException("Error while communicating with Bulksms API.", ex);
        }

        logger.info(String.format("To: %s >>> %s", phoneNumber, message));

        // simulate a failure
        if (new Random().nextInt(10) % 5 == 0) {
            throw new MessageSendException(500, "MSG0042", "Insufficient credits to send message");
        }
    }

    @Override
    public void close() {
    }
}
