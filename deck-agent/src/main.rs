use rocket::{launch,routes};

// fn main() {
//     println!("Hello, world!");
// }




#[macro_use] extern crate rocket;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index])
}

