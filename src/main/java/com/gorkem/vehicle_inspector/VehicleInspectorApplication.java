package com.gorkem.vehicle_inspector;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class VehicleInspectorApplication {

	public static void main(String[] args) {
		SpringApplication.run(VehicleInspectorApplication.class, args);
	}

}
