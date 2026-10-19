package com.aponti.ciclo_circadiano.controller;

import com.aponti.ciclo_circadiano.config.JwtService;
import com.aponti.ciclo_circadiano.model.UserModel;
import com.aponti.ciclo_circadiano.questionario.BancoDePerguntas;
import com.aponti.ciclo_circadiano.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

import static org.hamcrest.Matchers.isIn;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class EndpointsProtegidosTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private BancoDePerguntas bancoDePerguntas;

    private String token;

    @BeforeEach
    void prepararUsuario() {
        userRepository.save(new UserModel(
                null,
                "Usuário protegido",
                "protegido@email.com",
                passwordEncoder.encode("senha12345"),
                null));
        token = "Bearer " + jwtService.generateToken("protegido@email.com");
    }

    @Test
    @DisplayName("GET /perguntas com token retorna todas as perguntas")
    void listaPerguntasComToken() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get("/perguntas")
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(bancoDePerguntas.listar().size()));
    }

    @Test
    @DisplayName("GET /avaliacoes sem avaliações retorna lista vazia")
    void listaAvaliacoesVazia() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get("/avaliacoes")
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    @DisplayName("GET /avaliacoes lista a avaliação criada pelo usuário")
    void listaAvaliacaoCriada() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.post("/avaliacoes")
                        .header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(corpoComTodasAsRespostas()))
                .andExpect(status().isCreated());

        mockMvc.perform(MockMvcRequestBuilders.get("/avaliacoes")
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    @DisplayName("GET /avaliacoes sem token é negado")
    void listaAvaliacoesSemToken() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get("/avaliacoes"))
                .andExpect(status().is(isIn(List.of(401, 403))));
    }

    @Test
    @DisplayName("Token inválido é negado")
    void rejeitaTokenInvalido() throws Exception {
        mockMvc.perform(MockMvcRequestBuilders.get("/perguntas")
                        .header("Authorization", "Bearer token.invalido.qualquer"))
                .andExpect(status().is(isIn(List.of(401, 403))));
    }

    private String corpoComTodasAsRespostas() {
        var respostas = bancoDePerguntas.listar().stream()
                .map(pergunta -> """
                        {"perguntaId":%d,"opcaoId":%d}
                        """.formatted(pergunta.id(), pergunta.opcoes().getFirst().id()))
                .collect(Collectors.joining(","));

        return """
                {"respostas":[%s]}
                """.formatted(respostas);
    }
}
