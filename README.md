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

#### 1. setup Database

```
$ docker-compose up db
```

#### 2. build application

```
$ vapor build
```

#### 4. migrate

```
$ vapor run migrate
```

#### 5. run application

```
$ vapor run
```

#### 6. enjoy

```
$ curl -X localhost:8080
```

