# Ciclo Circadiano

Aplicação web para autoavaliação de hábitos relacionados ao sono e ao ritmo circadiano. O questionário considera dez perguntas sobre regularidade dos horários, saúde do sono, exposição à luz e consumo de estimulantes. Ao concluir, a aplicação apresenta uma pontuação geral, resultados por domínio e sugestões para reflexão. O resultado é informativo e não substitui uma avaliação profissional.

## Tecnologias

- Java 21 e Spring Boot 4.1.1
- Maven (Maven Wrapper)
- MySQL 8.4
- HTML, CSS e JavaScript
- Docker e Docker Compose (execução conteinerizada)

## Estrutura relevante

```text
.
├── docker-compose.yml
├── backend/
│   └── ciclo-circadiano/
│       ├── Dockerfile
│       ├── .env                 # criado localmente; não versionar
│       ├── .env.example         # modelo de variáveis
│       ├── mvnw
│       ├── pom.xml
│       └── src/
└── frontend/
    ├── Dockerfile
    ├── nginx.conf
    └── index.html
```

## Executar com Docker Compose (recomendado)

Pré-requisitos: Docker Engine/Desktop com o comando `docker compose` disponível.

1. Crie o arquivo de ambiente a partir do modelo:

   **PowerShell:**
   ```powershell
   Copy-Item backend/ciclo-circadiano/.env.example backend/ciclo-circadiano/.env
   ```

   Edite `backend/ciclo-circadiano/.env` e defina senhas fortes para `DB_PASSWORD` e `MYSQL_ROOT_PASSWORD`, além de uma `JWT_SECRET` com pelo menos 32 caracteres. Não compartilhe nem versione esse arquivo.

2. Na raiz do repositório, passe o arquivo de ambiente explicitamente (o Compose usa esse arquivo também para interpolar as variáveis `${...}`) e inicie os serviços:

   ```bash
   docker compose --env-file backend/ciclo-circadiano/.env up --build -d
   ```

3. Acesse:
   - Frontend: http://localhost:8081
   - API: http://localhost:8080/api

4. Para acompanhar os logs:
   ```bash
   docker compose --env-file backend/ciclo-circadiano/.env logs -f
   ```
   Para ver o estado dos serviços:
   ```bash
   docker compose --env-file backend/ciclo-circadiano/.env ps
   ```

5. Para parar os serviços:
   ```bash
   docker compose --env-file backend/ciclo-circadiano/.env down
   ```

   Os dados do MySQL ficam no volume nomeado `dados_mysql` e são preservados ao executar `docker compose --env-file backend/ciclo-circadiano/.env down`. Para apagar também os dados persistidos, use `docker compose --env-file backend/ciclo-circadiano/.env down -v` — **isso remove permanentemente o volume do banco**.

### Para que serve cada arquivo Docker

- `docker-compose.yml`: define e conecta os três serviços (`frontend`, `backend` e `banco`), publica as portas, configura a persistência do MySQL e aguarda o banco ficar saudável antes de iniciar o backend.
- `backend/ciclo-circadiano/Dockerfile`: compila o backend com o Maven Wrapper em uma etapa de build e executa o JAR em uma imagem Java 21 JRE separada, usando usuário sem privilégios.
- `frontend/Dockerfile`: empacota os arquivos estáticos em uma imagem Nginx.
- `frontend/nginx.conf`: configura o Nginx para servir os arquivos do frontend.
- `backend/ciclo-circadiano/.env`: guarda configurações sensíveis localmente; deve ser criado a partir do `.env.example` e mantido fora do Git.

### Observações importantes sobre Docker

- Dentro do Compose, o backend acessa o MySQL pelo hostname `banco`, e não por `localhost`. O Compose define `DB_URL` corretamente no container do backend.
- O navegador acessa o frontend em `localhost:8081` e a API em `localhost:8080`. Como o JavaScript do frontend roda no navegador do usuário, a URL da API configurada no frontend deve continuar apontando para `http://localhost:8080` quando a aplicação é acessada localmente.
- O Compose pressupõe que o backend lê as variáveis `DB_URL`, `DB_USER`, `DB_PASSWORD` e `JWT_SECRET`, como descrito neste README. Se o código usar nomes diferentes ou carregar `.env` por uma biblioteca específica, ajuste as variáveis conforme a implementação.
- O MySQL usa um volume nomeado para preservar os dados entre reinicializações.
- A configuração usa `depends_on` com healthcheck para evitar que o backend tente conectar ao banco antes de ele aceitar conexões.

## Executar sem Docker

1. Instale o JDK 21 e o MySQL.
2. Crie um banco de dados MySQL vazio chamado `banco_circadiano`.
3. Configure `backend/ciclo-circadiano/.env` com as variáveis necessárias:

   ```properties
   DB_URL=jdbc:mysql://localhost:3306/banco_circadiano?useSSL=false&allowPublicKeyRetrieval=true
   DB_USER=seu_usuario
   DB_PASSWORD=sua_senha
   JWT_SECRET=uma_chave_secreta_com_pelo_menos_32_caracteres
   ```

4. Inicie o backend:

   **PowerShell:**
   ```powershell
   cd backend/ciclo-circadiano
   .\mvnw.cmd spring-boot:run
   ```

   A API estará disponível em http://localhost:8080/api. O Hibernate atualiza as tabelas conforme as entidades da aplicação.

5. Sirva os arquivos da pasta `frontend` com um servidor web local e abra `index.html`. A interface usa a API em `http://localhost:8080`.

Para executar os testes automatizados do backend:

```powershell
cd backend/ciclo-circadiano
.\mvnw.cmd test
```

## Uso da aplicação

1. Crie uma conta na tela de cadastro.
2. Entre com e-mail e senha.
3. Inicie a avaliação e responda às dez perguntas. Considere, de preferência, os últimos 14 dias.
4. Consulte a pontuação geral, a classificação e os resultados por domínio.
5. Na página inicial, consulte a avaliação mais recente ou saia da conta.

As respostas do questionário feitas pela interface web são processadas no dispositivo e não são enviadas ao backend. As rotas de avaliação documentadas abaixo permitem consultar e registrar avaliações pela API.

## API

Todas as rotas usam o prefixo `/api`. As rotas de cadastro e login são públicas. As demais exigem o cabeçalho:

```http
Authorization: Bearer <token>
```

### Rotas públicas

| Método | Rota | Descrição | Respostas principais |
| --- | --- | --- | --- |
| `POST` | `/api/auth/register` | Cadastra um usuário | `201` sucesso, `409` e-mail já cadastrado, `400` dados inválidos |
| `POST` | `/api/auth/login` | Autentica um usuário | `200` sucesso, `401` credenciais inválidas, `400` dados inválidos |

Exemplo de cadastro:

```json
{
  "nome": "Nome do usuário",
  "email": "usuario@example.com",
  "senha": "senha12345"
}
```

Exemplo de login:

```json
{
  "email": "usuario@example.com",
  "senha": "senha12345"
}
```

As respostas de sucesso incluem o token de autenticação. Envie o token como `Bearer <token>` nas rotas protegidas.

### Rotas autenticadas

| Método | Rota | Descrição | Respostas principais |
| --- | --- | --- | --- |
| `GET` | `/api/perguntas` | Lista as perguntas e opções do questionário | `200` sucesso |
| `GET` | `/api/avaliacoes/ultima` | Consulta a avaliação mais recente do usuário | `200` com avaliação, `204` se ainda não houver |
| `GET` | `/api/avaliacoes` | Lista as avaliações do usuário | `200` sucesso |
| `POST` | `/api/avaliacoes` | Cria uma avaliação com todas as respostas | `201` sucesso, `400` respostas inválidas ou incompletas |

Para criar uma avaliação, consulte primeiro `GET /api/perguntas` e envie uma resposta para cada pergunta, usando os identificadores retornados:

```json
{
  "respostas": [
    {
      "perguntaId": 1,
      "opcaoId": 1
    },
    {
      "perguntaId": 2,
      "opcaoId": 2
    }
  ]
}
```

O exemplo mostra apenas duas respostas. Na requisição real, inclua uma resposta para cada pergunta listada pela API.
