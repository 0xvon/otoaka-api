## Rocket API

### Environment

- Swift 5.2
- Vapor 4.0 (Server Side Swift)
- Xcode 11.7
- Fluent 4.0 (ORM)
- Fluent MySQL Driver
- Kubernetes
- EKS
- Clean Architecture

### How to run

#### 1. setup

```
$ docker-compose up --build app
```

#### 2. migrate

```
$ vapor run migrate
```

#### 3. enjoy

```
$ curl -X localhost:8080
```

