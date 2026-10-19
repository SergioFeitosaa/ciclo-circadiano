package com.aponti.ciclo_circadiano;

import com.aponti.ciclo_circadiano.repository.UserRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import javax.sql.DataSource;
import java.sql.Connection;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
class ConexaoBancoTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private UserRepository userRepository;

    @Test
    @DisplayName("Abre uma conexão válida com o banco de dados")
    void abreConexaoValida() throws Exception {
        try (Connection conexao = dataSource.getConnection()) {
            assertTrue(conexao.isValid(2));
        }
    }

    @Test
    @DisplayName("Consulta a tabela de usuários pelo repositório")
    void consultaTabelaDeUsuarios() {
        assertDoesNotThrow(() -> userRepository.count());
    }
}
