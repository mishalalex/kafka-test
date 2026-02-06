package simulations;

import io.gatling.javaapi.core.ScenarioBuilder;
import io.gatling.javaapi.core.Simulation;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.ByteArrayDeserializer;
import org.apache.kafka.common.serialization.ByteArraySerializer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.galaxio.gatling.kafka.javaapi.protocol.KafkaProtocolBuilder;
import org.galaxio.gatling.kafka.javaapi.protocol.KafkaProtocolBuilderBase;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static io.gatling.javaapi.core.CoreDsl.atOnceUsers;
import static io.gatling.javaapi.core.CoreDsl.scenario;
import static org.galaxio.gatling.kafka.javaapi.KafkaDsl.kafka;


public class KafkaRequestReplyJavaSimulation extends Simulation {

    private final String bootstrap = System.getProperty("kafka.bootstrap", "localhost:9092");
    private final String requestTopic = System.getProperty("kafka.request.topic", "requests");
    private final String replyTopic = System.getProperty("kafka.reply.topic", "replies");
    private final String groupId = System.getProperty("kafka.group.id", "gatling-rr-" + UUID.randomUUID());
    private final String appId = System.getProperty("kafka.application.id", groupId);
    private final int timeoutSec = Integer.parseInt(System.getProperty("kafka.reply.timeoutSec", "60"));
    private final int users = Integer.parseInt(System.getProperty("users", "1"));

    KafkaProtocolBuilder protocol = new KafkaProtocolBuilderBase()
            .producerSettings(Map.of(
                    ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrap,
                    ProducerConfig.ACKS_CONFIG, "1",
                    ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName(),
                    ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, ByteArraySerializer.class.getName()
            ))
            .consumeSettings(Map.of(
                    ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrap,
                    ConsumerConfig.GROUP_ID_CONFIG, groupId,
                    ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName(),
                    ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, ByteArrayDeserializer.class.getName(),
                    ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest",
                    ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "true"
            ))
            .timeout(Duration.ofSeconds(60));


    ScenarioBuilder scn = scenario("kafka-rr-once")
            .exec(session -> {
                String corrId = UUID.randomUUID().toString();
                String sentAt = Instant.now().toString();
                String payload = String.format("{\"id\":\"%s\",\"msg\":\"hello\",\"sentAt\":\"%s\"}", corrId, sentAt);

                return session.set("corrId", corrId).set("payload", payload);
            })
            .exec(
                    kafka("rr").requestReply()
                            .requestTopic(requestTopic)
                            .replyTopic(replyTopic)
                            .send("#{corrId}", "#{payload}")
            )
            .exitHereIfFailed();

    {
        setUp(
                scn.injectOpen(atOnceUsers(users))
        ).protocols(protocol);
    }
}
